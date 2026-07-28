use std::cell::RefCell;
use std::ffi::{c_char, CString};

thread_local! {
    static LAST_ERROR: RefCell<Option<String>> = const { RefCell::new(None) };
}

/// Returns the most recent error message (empty string if none), as a freshly
/// allocated C string the caller must free with `openalias_string_free`.
#[no_mangle]
pub unsafe extern "C" fn openalias_last_error_message() -> *mut c_char {
    let msg = LAST_ERROR.with(|prev| prev.borrow_mut().take()).unwrap_or_default();
    CString::new(msg).unwrap_or_default().into_raw()
}

pub fn set_last_error(msg: impl Into<String>) {
    let msg = msg.into();
    log::warn!("openalias error: {msg}");
    LAST_ERROR.with(|prev| *prev.borrow_mut() = Some(msg));
}
