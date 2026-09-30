# otp

TOTP codes from the command line and the macOS menubar.

## CLI

```sh
brew install oath-toolkit
ln -sf "$PWD/otp" /usr/local/bin/otp
```

Add your secrets to `~/.otpkeys`, one per line:

```
github=BASE32SECRET
aws-prod=BASE32SECRET
```

`otp github` copies the current code to the clipboard.

## Menubar app

```sh
menubar/build.sh
open ~/Applications/OTP.app
```

A key icon in the menubar lists everything in `~/.otpkeys`. Pick one to copy its code. Enable "Launch at Login" from the same menu.
