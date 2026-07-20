//! OpenAlias resolver with end-to-end DNSSEC validation, routed over Tor's
//! SOCKS proxy. DNS is fetched via TCP through the proxy (Tor has no UDP) and
//! validated locally by hickory (RRSIG → DS → root trust anchor), so no
//! resolver is trusted and no DNS leaks outside Tor.

mod error;

use std::ffi::{c_char, CStr, CString};
use std::future::Future;
use std::io;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::pin::Pin;
use std::time::Duration;

use hickory_proto::dnssec::Proof;
use hickory_proto::rr::RecordType;
use hickory_proto::runtime::iocompat::AsyncIoTokioAsStd;
use hickory_proto::runtime::{RuntimeProvider, TokioHandle, TokioTime};
use hickory_proto::xfer::Protocol;
use hickory_resolver::config::{NameServerConfig, ResolverConfig, ResolverOpts};
use hickory_resolver::name_server::GenericConnector;
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
        local_addr: SocketAddr,
        _server_addr: SocketAddr,
    ) -> Pin<Box<dyn Send + Future<Output = io::Result<Self::Udp>>>> {
        // Unused: the resolver is TCP-only (Tor has no UDP). Provided to satisfy
        // the trait.
        Box::pin(async move { TokioUdpSocket::bind(local_addr).await })
    }
}

/// Resolve an OpenAlias `domain` for `asset` (e.g. "btc") over Tor with DNSSEC
/// validation. Returns a newly-allocated address string, or NULL on failure
/// (see `openalias_last_error_message`). Caller frees with `openalias_string_free`.
///
/// # Safety
/// `domain` and `asset` must be valid NUL-terminated C strings.
#[no_mangle]
pub unsafe extern "C" fn openalias_resolve(
    domain: *const c_char,
    asset: *const c_char,
    socks_port: u16,
) -> *mut c_char {
    let domain = match cstr(domain) {
        Some(s) => s,
        None => return ret_err("invalid domain"),
    };
    let asset = match cstr(asset) {
        Some(s) => s,
        None => return ret_err("invalid asset"),
    };

    let runtime = match RUNTIME.as_ref() {
        Ok(rt) => rt,
        Err(e) => return ret_err(format!("tokio runtime: {e}")),
    };

    match runtime.block_on(resolve(&domain, &asset, socks_port)) {
        Ok(addr) => match CString::new(addr) {
            Ok(c) => c.into_raw(),
            Err(_) => ret_err("address contained NUL"),
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

async fn resolve(domain: &str, asset: &str, socks_port: u16) -> Result<String, String> {
    let proxy = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), socks_port);

    let mut config = ResolverConfig::new();
    for (ip, host) in UPSTREAMS {
        // DNS-over-HTTPS on 443 (POST {host}/dns-query). The TLS cert is verified
        // against `host`; the answer's DNSSEC chain is validated locally.
        let mut ns = NameServerConfig::new(SocketAddr::new(IpAddr::V4(*ip), 443), Protocol::Https);
        ns.tls_dns_name = Some(host.to_string());
        config.add_name_server(ns);
    }

    let mut opts = ResolverOpts::default();
    opts.validate = true; // local DNSSEC validation against the root trust anchor
    opts.timeout = TCP_TIMEOUT;

    let provider = SocksRuntimeProvider { proxy, handle: TokioHandle::default() };
    let resolver = Resolver::builder_with_config(config, GenericConnector::new(provider))
        .with_options(opts)
        .build();

    let fqdn = if domain.ends_with('.') {
        domain.to_string()
    } else {
        format!("{domain}.")
    };

    let lookup = resolver
        .lookup(fqdn, RecordType::TXT)
        .await
        .map_err(|e| format!("lookup failed: {e}"))?;

    // Require DNSSEC-secure: reject unsigned (insecure) and bogus answers.
    let proofs: Vec<Proof> = lookup.records().iter().map(|r| r.proof()).collect();
    if !proofs.iter().all(|p| *p == Proof::Secure) {
        return Err(format!(
            "answer is not DNSSEC-secure (records={}, proofs={:?})",
            proofs.len(),
            proofs
        ));
    }

    let prefix = format!("oa1:{}", asset.to_lowercase());
    let mut txt_seen = 0usize;
    for record in lookup.record_iter() {
        if let Some(txt) = record.data().as_txt() {
            txt_seen += 1;
            let joined: String = txt
                .iter()
                .map(|b| String::from_utf8_lossy(b).into_owned())
                .collect();
            if let Some(addr) = parse_oa1(&joined, &prefix) {
                return Ok(addr);
            }
        }
    }
    Err(format!("no {prefix} record found ({txt_seen} TXT record(s) present)"))
}

/// Parses a concatenated TXT string for an OpenAlias entry matching `prefix`,
/// returning its `recipient_address`.
fn parse_oa1(txt: &str, prefix: &str) -> Option<String> {
    // OpenAlias: `oa1:<asset> recipient_address=ADDR; recipient_name=NAME; ...`
    // The prefix and first key share the first (space-separated) segment, so
    // strip the prefix before splitting the key=value fields on ';'.
    let rest = txt.trim_start().strip_prefix(prefix)?;
    for field in rest.split(';') {
        if let Some(value) = field.trim().strip_prefix("recipient_address=") {
            let value = value.trim();
            if !value.is_empty() {
                return Some(value.to_string());
            }
        }
    }
    None
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
    use super::parse_oa1;

    #[test]
    fn parses_btc_recipient() {
        let txt = "oa1:btc recipient_address=1BoatSLRHtKNngkdXEeobR76b53LETtpyT; recipient_name=Donate;";
        assert_eq!(
            parse_oa1(txt, "oa1:btc").as_deref(),
            Some("1BoatSLRHtKNngkdXEeobR76b53LETtpyT")
        );
    }

    #[test]
    fn ignores_other_assets() {
        let txt = "oa1:xmr recipient_address=4xxx; recipient_name=x;";
        assert_eq!(parse_oa1(txt, "oa1:btc"), None);
    }

    #[test]
    fn ignores_non_openalias() {
        assert_eq!(parse_oa1("v=spf1 include:_spf.example.com ~all", "oa1:btc"), None);
    }
}
