// The address book store lives in wallet-core (wallet_domain), shared with
// Spice; kept under this path so call sites are unchanged. It carries the
// shared-preferences migration this app needed.
export 'package:wallet_domain/wallet_domain.dart'
    show readEncodedContacts, writeEncodedContacts, clearContacts;
