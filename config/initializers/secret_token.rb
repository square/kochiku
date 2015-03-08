# Be sure to restart your server when you modify this file.

# Your secret key is used for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!

# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.

# Use a random hex since so we don't currently use cookies for anything in
# Kochiku
Kochiku::Application.config.secret_key_base = SecureRandom.hex(64)
