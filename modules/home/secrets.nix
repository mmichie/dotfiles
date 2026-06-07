{ config, lib, ... }:
{
  sops = {
    age = {
      keyFile = config.my.sops.keyFile;
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

      "cargo_credentials" = {
        format = "binary";
        sopsFile = ../../secrets/cargo-credentials;
        path = "${config.home.homeDirectory}/.cargo/credentials.toml";
        mode = "0400";
      };

      # GAM7 static credentials. The mutable oauth2.txt (rewritten on token
      # refresh) and gam.cfg stay machine-local — carried between machines by
      # `just secrets-backup`, not sops.
      "gam_client_secrets" = {
        format = "binary";
        sopsFile = ../../secrets/gam-client-secrets;
        path = "${config.home.homeDirectory}/.gam/client_secrets.json";
        mode = "0400";
      };

      "gam_oauth2service" = {
        format = "binary";
        sopsFile = ../../secrets/gam-oauth2service;
        path = "${config.home.homeDirectory}/.gam/oauth2service.json";
        mode = "0400";
      };
    }
    // lib.optionalAttrs config.my.isWork {
      # Work-only secret — encrypted to mim-moab's age key only. Declared only
      # on hosts where my.isWork = true. Personal machines can't decrypt the
      # blob even if they pulled it.
      "zshrc_work_local" = {
        format = "binary";
        sopsFile = ../../secrets/zshrc-work-local;
        path = "${config.home.homeDirectory}/.zshrc-work-local";
        mode = "0400";
      };
    };
  };
}
