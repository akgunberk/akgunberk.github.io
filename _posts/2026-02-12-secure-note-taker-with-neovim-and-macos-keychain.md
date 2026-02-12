---
layout: post
title: Secure note taker with neovim and MacOS keychain
date: 2026-02-12 20:19 +0300
tags: [neovim, macos, security, encryption, terminal, openssl, keychain, shell, productivity]
---

I am not sure if I told you before but I am a terminal person and a huge neovim/vim fan.

I think it can be placed in most influential softwares besides git etc.

I had some aliases in my **.zsh** recently which allows me to write quick daily notes.
It is super simple, creating/editing a file in my notes folder with nvim. Auto name
my note with the date for traceability.

```bash
alias note='nvim ~/Documents/notes/$(date +"%d-%m-%Y").md'
alias notes='nvim ~/Documents/notes'
```

You may suggest me tools like, evernote, notion or
obsidian but, I got never felt comfy using them, I spent my time mostly in the terminal during
the day, and, I like to use the bare minimum tool if I can and It provides what I need.

So, that's the reason I'm still using bare and simple neovim for note-taking.

Since, I am writing about security and cryptographic functions lately.
I've decided to upgrade my tools in terms of security, using `openssl` and
built-in keychain of MacOS.

I've updated **note** alias with this function in my **.zshrc**:
It uses, openssl, security, mktemp and neovim.

- It generates a rand strong password if not generated already.
- It creates a dedicated keychain-db if not created with 5 minute auto-lock.
- Store the password in keychain.
- And prompt keychain password screen, when user tries to edit with `note` command in cli.
- Uses the password stored in keychain to encrypt and decrypt the note
- Creates a tmp markdown file to edit the note in nvim
- Encrypts the note again and locks the keychain after closing nvim and removes tmp file.

```bash
NOTES_DIR="$HOME/.secure-notes"

note() {
  mkdir -p "$NOTES_DIR"
  local file="$NOTES_DIR/note-$(date +"%d-%m-%Y").md"
  local tmp="$(mktemp -t note).md"
  local SERVICE="notes-key"
  local KC="$HOME/Library/Keychains/notes.keychain-db"
  local ACCOUNT="$USER"

  # Create dedicated keychain if missing
  if [ ! -f "$KC" ]; then
    echo "Creating dedicated notes keychain..."
    security create-keychain -p "" notes.keychain-db
    security set-keychain-settings -lut 300 notes.keychain-db
    security list-keychains -d user -s notes.keychain-db login.keychain-db
    echo "Keychain created (auto-lock 5 minutes)."
  fi

  # Try retrieving existing password
  local PASS
  PASS=$(security find-generic-password \
  -a "$ACCOUNT" \
  -s "$SERVICE" \
  -w \
  "$KC" 2>/dev/null)

  # If password does not exist, generate and store
  if [ -z "$PASS" ]; then
    echo "No password found. Generating strong password..."
    PASS=$(openssl rand -base64 48)

    security add-generic-password \
      -a "$ACCOUNT" \
      -s "$SERVICE" \
      -w "$PASS" \
      -U \
      "$KC"

    echo "Password stored in dedicated keychain."
  fi

  if [ -f "$file" ]; then
    openssl enc -d -aes-256-cbc -pbkdf2 \
      -in "$file" \
      -out "$tmp" \
      -pass stdin <<<"$pass" 2>/dev/null || {
        echo "Decryption failed"
        rm -f "$tmp"
        unset pass
        return 1
      }
  fi

  nvim "$tmp"

  openssl enc -aes-256-cbc -pbkdf2 \
    -in "$tmp" \
    -out "$file" \
    -pass stdin <<<"$pass"

  rm -f "$tmp"
  unset pass

  security lock-keychain $KC
}
```

And here is the updated version of, `notes` command to select and edit existed notes
and to create new one with a different name:

```bash
# make sure to brew 'gum' before this

notes() {
  mkdir -p "$NOTES_DIR"

  local selection
  selection=$(
    {
      for f in "$NOTES_DIR"/*.md; do
        [ -e "$f" ] && basename "$f" .md
      done
      echo "[Create new note]"
    } | gum filter
  ) || return 1

  if [ "$selection" = "[Create new note]" ]; then
    local name
    name=$(gum input --placeholder "Note name (without extension)") || return 1
    [ -z "$name" ] && return 1
    note "$NOTES_DIR/$name-$(date +"%d-%m-%Y")"
  else
    [ -z "$selection" ] && return 1
    note "$NOTES_DIR/$selection"
  fi
}
```

And, it is what it is, a simple yet secure note-taking system which utilizes neovim.

Until next time,
Berk
