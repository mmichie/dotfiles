{ config, ... }:
{
  sops = {
    age = {
      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      generateKey = false;
    };

    defaultSopsFile = ../../secrets/atuin-key;
    validateSopsFiles = true;

    secrets = {
      "atuin_key" = {
        format = "binary";
        sopsFile = ../../secrets/atuin-key;
        path = "${config.home.homeDirectory}/.local/share/atuin/key";
        mode = "0400";
      };

      "zshrc_local" = {
        format = "binary";
        sopsFile = ../../secrets/zshrc-local;
        path = "${config.home.homeDirectory}/.zshrc.local";
        mode = "0400";
      };

      "dotenv" = {
        format = "binary";
        sopsFile = ../../secrets/env;
        path = "${config.home.homeDirectory}/.env";
        mode = "0400";
      };

      "cargo_credentials" = {
        format = "binary";
        sopsFile = ../../secrets/cargo-credentials;
        path = "${config.home.homeDirectory}/.cargo/credentials.toml";
        mode = "0400";
      };
    };
  };
}
