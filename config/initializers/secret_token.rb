# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.

# Use a random hex since so we don't have a secret stored in git
# and we don't use cookies for anything in kochiku
Kochiku::Application.config.secret_token = SecureRandom.hex(64)
