// Contact and ContactModel live in wallet-core (wallet_domain), shared with
// Spice; kept under this path so call sites are unchanged.
//
// The shared Contact holds one address per chain. Skylight shows the Monero one
// and nothing else today; the map is what it needs once Serai swaps give it
// other chains, and it means both apps read and write one stored format.
export 'package:wallet_domain/wallet_domain.dart' show Contact, ContactModel;
