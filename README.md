# mac-rdp-yubikey

Remote Desktop from a Mac to a Windows PC, with the **YubiKey (or any FIDO2 security key)
plugged into the Mac usable inside the remote session**, e.g. for WebAuthn / passkey logins
in Chrome or Edge on the Windows PC. You touch the key on the Mac.

## Why

On Windows, `mstsc` forwards WebAuthn requests to the client's security key via the RDP
WebAuthn channel ([MS-RDPEWA]). Microsoft's *Windows App* for macOS does not support this
for connections to a normal PC (only a preview for Azure Virtual Desktop / Windows 365,
Entra ID sign-ins only), and it has no USB redirection either.

[FreeRDP](https://github.com/FreeRDP/FreeRDP) implements the client side of [MS-RDPEWA]
since 3.25.0 (talking to the key through libfido2). This repo is a small launcher around
Homebrew's `sdl-freerdp` that enables the channel and handles login and certificate pinning.
No USB-over-network tool and no software on the Windows PC is needed.

[MS-RDPEWA]: https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-rdpewa/

## Requirements

- macOS with Homebrew, `brew install freerdp` (3.33.1 or newer recommended)
- A FIDO2 security key (e.g. YubiKey) with FIDO enabled, plugged into the Mac
- Windows 10/11 PC with Remote Desktop enabled. WebAuthn redirection is allowed by default;
  it must not be disabled by the policy *Remote Desktop Session Host → Device and Resource
  Redirection → Do not allow WebAuthn redirection*.

## Setup

```sh
git clone https://github.com/LogicsSoftwareGmbH/mac-rdp-yubikey.git
cd mac-rdp-yubikey
cp config.example config.local   # set HOST
```

## Usage

Double-click `rdp-yubikey.command` in Finder (opens Terminal), or run `./rdp-yubikey.command`.

- **First connect:** shows the PC's certificate name and SHA-256 fingerprint and asks whether
  to trust it. The answer is saved to `config.local`; later connects only accept that
  certificate.
- **Username:** asked every time, the last one is remembered (`.last-user`).
- **Password:** typed as `***`. It is passed to FreeRDP via a file descriptor
  (`/args-from:fd:3`), not on the command line, so it doesn't appear in `ps`, and it is not stored.
- When a website asks for the security key inside the session, touch the key on the Mac.
  If the key has a FIDO PIN, FreeRDP asks for it.
- Session log: `rdp-yubikey.log`, with debug output of the WebAuthn channel
  (`com.freerdp.channels.rdpewa`).

`config.local`, `.last-user` and the log are gitignored.

## Limitations

- Only hardware keys that libfido2 can talk to. Touch ID, iCloud Keychain or 1Password
  passkeys on the Mac are not forwarded.
- Starting a sign-in without a key plugged in fails without a clear message.
- No account picker when a site has several credentials on the same key
  ([FreeRDP PR #13623](https://github.com/FreeRDP/FreeRDP/pull/13623), open).
