//! OpenAlias resolver with end-to-end DNSSEC validation, routed over Tor's
//! SOCKS proxy. DNS is fetched via TCP through the proxy (Tor has no UDP) and
//! validated locally by hickory (RRSIG → DS → root trust anchor), so no
//! resolver is trusted and no DNS leaks outside Tor.
//!
//! The FFI surface is deliberately thin: it returns the DNSSEC-validated TXT
//! records at a name, and Dart parses the OpenAlias v1 and v2 grammars on top
//! (see `lib/src/openalias_records.dart`). That split keeps the record parsing
//! and selection unit-testable without a native build, while the part that has
//! to be trustworthy — "these bytes really are what the signed zone published"
//! — stays here.

mod error;

use std::ffi::{c_char, CStr, CString};
use std::future::Future;
use std::io;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::pin::Pin;
use std::sync::Arc;
use std::time::Duration;

use hickory_proto::dnssec::Proof;
use hickory_proto::rr::{RData, RecordType};
use hickory_resolver::config::{NameServerConfig, ResolverConfig, ResolverOpts};
use hickory_resolver::net::runtime::iocompat::AsyncIoTokioAsStd;
use hickory_resolver::net::runtime::{RuntimeProvider, TokioHandle, TokioTime};
use hickory_resolver::Resolver;
use lazy_static::lazy_static;
use tokio::net::{TcpStream as TokioTcpStream, UdpSocket as TokioUdpSocket};
use tokio::runtime::{Builder, Runtime};
use tokio_socks::tcp::Socks5Stream;

use crate::error::set_last_error;

lazy_static! {
    static ref RUNTIME: io::Result<Runtime> = Builder::new_multi_thread().enable_all().build();
}

/// Public recursive resolvers queried (over Tor) for the signed records, as
/// DNS-over-HTTPS (port 443) — Tor exits reject plain DNS (53). They only
/// transport the signed data — validation happens locally — so a malicious
/// resolver can withhold an answer but cannot forge one. Each entry is the
/// resolver IP and the TLS/host name used for its certificate + DoH endpoint.
const UPSTREAMS: &[(Ipv4Addr, &str)] = &[
    (Ipv4Addr::new(9, 9, 9, 9), "dns.quad9.net"),
    (Ipv4Addr::new(1, 1, 1, 1), "cloudflare-dns.com"),
];

const TCP_TIMEOUT: Duration = Duration::from_secs(30);

/// A hickory runtime provider whose TCP connections are dialed through a
/// SOCKS5 proxy (Tor). UDP is unused (resolver is configured TCP-only).
#[derive(Clone)]
struct SocksRuntimeProvider {
    proxy: SocketAddr,
    // A persistent handle whose JoinSet outlives the spawned connection driver.
    // Returning a fresh TokioHandle per call would drop the JoinSet and abort
    // the h2 driver task → "receiver was canceled". hickory's own provider keeps
    // one shared handle for exactly this reason.
    handle: TokioHandle,
}

impl RuntimeProvider for SocksRuntimeProvider {
    type Handle = TokioHandle;
    type Timer = TokioTime;
    type Udp = TokioUdpSocket;
    type Tcp = AsyncIoTokioAsStd<Socks5Stream<TokioTcpStream>>;

    fn create_handle(&self) -> Self::Handle {
        self.handle.clone()
    }

    fn connect_tcp(
        &self,
        server_addr: SocketAddr,
        _bind_addr: Option<SocketAddr>,
        _timeout: Option<Duration>,
    ) -> Pin<Box<dyn Send + Future<Output = io::Result<Self::Tcp>>>> {
        let proxy = self.proxy;
        Box::pin(async move {
            let stream = Socks5Stream::connect(proxy, server_addr)
                .await
                .map_err(|e| io::Error::new(io::ErrorKind::Other, e))?;
            Ok(AsyncIoTokioAsStd(stream))
        })
    }

    fn bind_udp(
        &self,
        _local_addr: SocketAddr,
        _server_addr: SocketAddr,
    ) -> Pin<Box<dyn Send + Future<Output = io::Result<Self::Udp>>>> {
        // Refused, never bound. Tor carries no UDP, so a UDP query could only
        // leave over clearnet. The resolver is configured with DoH name servers
        // exclusively and never asks for UDP; failing here means that if that
        // ever changed, the lookup would fail closed instead of leaking which
        // alias the user is resolving.
        Box::pin(async move {
            Err(io::Error::new(
                io::ErrorKind::Unsupported,
                "UDP is unavailable: OpenAlias DNS must go through the Tor SOCKS proxy",
            ))
        })
    }
}

/// Fetches the TXT records at `name` over Tor, requiring a DNSSEC-secure answer.
///
/// Returns a JSON array of strings — one entry per TXT record, each already
/// concatenated from its DNS character-strings (RFC 7208 §3.3) — or NULL on any
/// failure, which includes "no such name" and "name has no TXT records" (see
/// `openalias_last_error_message`). Callers treat NULL as "nothing usable
/// here": the OpenAlias v2 → v1 fallback is driven by which names returned
/// records, and an answer that could not be validated never returns records.
///
/// Caller frees the returned string with `openalias_string_free`.
///
/// # Safety
/// `name` must be a valid NUL-terminated C string.
#[no_mangle]
pub unsafe extern "C" fn openalias_secure_txt(
    name: *const c_char,
    socks_port: u16,
) -> *mut c_char {
    let name = match cstr(name) {
        Some(s) => s,
        None => return ret_err("invalid name"),
    };

    let runtime = match RUNTIME.as_ref() {
        Ok(rt) => rt,
        Err(e) => return ret_err(format!("tokio runtime: {e}")),
    };

    match runtime.block_on(secure_txt(&name, socks_port)) {
        Ok(records) => match CString::new(json_string_array(&records)) {
            Ok(c) => c.into_raw(),
            Err(_) => ret_err("record contained NUL"),
        },
        Err(msg) => ret_err(msg),
    }
}

/// Frees a string returned by this library.
///
/// # Safety
/// `ptr` must have been returned by this library and not already freed.
#[no_mangle]
pub unsafe extern "C" fn openalias_string_free(ptr: *mut c_char) {
    if !ptr.is_null() {
        drop(CString::from_raw(ptr));
    }
}

async fn secure_txt(name: &str, socks_port: u16) -> Result<Vec<String>, String> {
    let proxy = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), socks_port);

    // DNS-over-HTTPS (default /dns-query on 443). The TLS cert is verified
    // against `host`; the answer's DNSSEC chain is validated locally.
    let name_servers = UPSTREAMS
        .iter()
        .map(|(ip, host)| NameServerConfig::https(IpAddr::V4(*ip), Arc::from(*host), None))
        .collect();
    let config = ResolverConfig::from_parts(None, vec![], name_servers);

    let mut opts = ResolverOpts::default();
    opts.validate = true; // local DNSSEC validation against the root trust anchor
    opts.timeout = TCP_TIMEOUT;

    let provider = SocksRuntimeProvider { proxy, handle: TokioHandle::default() };
    let resolver = Resolver::builder_with_config(config, provider)
        .with_options(opts)
        .build()
        .map_err(|e| format!("resolver build failed: {e}"))?;

    // Non-ASCII labels are converted to their A-label (Punycode) form by
    // hickory when it parses the name, as OpenAlias requires (RFC 5890).
    let fqdn = if name.ends_with('.') { name.to_string() } else { format!("{name}.") };

    let lookup = resolver
        .lookup(fqdn, RecordType::TXT)
        .await
        .map_err(|e| format!("lookup failed: {e}"))?;

    // Require DNSSEC-secure: reject unsigned (insecure) and bogus answers.
    // hickory's `validate` only rejects *bogus* answers on its own — an unsigned
    // zone still yields records proven Insecure — so this check is what makes
    // the lookup fail closed.
    let proofs: Vec<Proof> = lookup.answers().iter().map(|r| r.proof).collect();
    if proofs.is_empty() || !proofs.iter().all(|p| *p == Proof::Secure) {
        return Err(format!(
            "answer is not DNSSEC-secure (records={}, proofs={:?})",
            proofs.len(),
            proofs
        ));
    }

    let mut records = Vec::new();
    for record in lookup.answers() {
        if let RData::TXT(txt) = &record.data {
            // A TXT record is one or more character-strings; concatenate them in
            // order, with no separator, before the record is parsed.
            records.push(
                txt.txt_data
                    .iter()
                    .map(|b| String::from_utf8_lossy(b).into_owned())
                    .collect::<String>(),
            );
        }
    }

    if records.is_empty() {
        return Err(format!("no TXT records at {name}"));
    }
    Ok(records)
}

/// Encodes `items` as a JSON array of strings. TXT records are attacker-chosen
/// bytes, so they are escaped rather than framed with a separator that a record
/// could contain.
fn json_string_array(items: &[String]) -> String {
    let mut out = String::from("[");
    for (i, item) in items.iter().enumerate() {
        if i > 0 {
            out.push(',');
        }
        json_escape_into(item, &mut out);
    }
    out.push(']');
    out
}

fn json_escape_into(s: &str, out: &mut String) {
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
}

unsafe fn cstr(ptr: *const c_char) -> Option<String> {
    if ptr.is_null() {
        return None;
    }
    CStr::from_ptr(ptr).to_str().ok().map(|s| s.to_string())
}

fn ret_err(msg: impl Into<String>) -> *mut c_char {
    set_last_error(msg);
    std::ptr::null_mut()
}

#[cfg(test)]
mod tests {
    use super::json_string_array;

    #[test]
    fn encodes_records() {
        let records = vec![
            "oa_version=2; network=xmr; address=888tNk;".to_string(),
            "oa1:xmr recipient_address=888tNk;".to_string(),
        ];
        assert_eq!(
            json_string_array(&records),
            r#"["oa_version=2; network=xmr; address=888tNk;","oa1:xmr recipient_address=888tNk;"]"#
        );
    }

    #[test]
    fn escapes_quotes_backslashes_and_controls() {
        let records = vec!["a\"b\\c\nd\te\u{1}f".to_string()];
        assert_eq!(json_string_array(&records), r#"["a\"b\\c\nd\te\u0001f"]"#);
    }

    #[test]
    fn encodes_empty_and_unicode() {
        assert_eq!(json_string_array(&[]), "[]");
        assert_eq!(json_string_array(&["münchen".to_string()]), "[\"münchen\"]");
    }
}
