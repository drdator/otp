# otp

TOTP codes from the command line and the macOS menubar. Secrets are stored in your login keychain.

## CLI

```sh
brew install oath-toolkit
ln -sf "$PWD/otp" /usr/local/bin/otp
```

```
otp add github      store a secret (prompts for it)
otp github          copy the current code to the clipboard
otp                 list names
otp rm github       delete a secret
```

When piped, `otp <name>` prints the code instead of copying it:

```sh
aws sts get-session-token --serial-number "$MFA_ARN" --token-code "$(otp aws-prod)"
```

## Menubar app

```sh
menubar/build.sh
open ~/Applications/OTP.app
```

A key icon in the menubar lists your keys. Pick one to copy its code. Add keys and enable "Launch at Login" from the same menu.

## Migrating from ~/.otpkeys

Earlier versions read `name=secret` lines from `~/.otpkeys`. To move them into the keychain:

```sh
while IFS== read -r name secret; do printf %s "$secret" | otp add "$name"; done < ~/.otpkeys
```

Then delete `~/.otpkeys`.
