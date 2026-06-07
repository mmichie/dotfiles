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

      # cargo (crates.io) and GAM credentials are NOT here: they live in
      # 1Password instead, to keep them out of the public repo entirely.
      #   - cargo:  `op plugin init cargo` -> aliased `cargo` injects the
      #             token at publish time (see ~/.config/op/plugins.sh).
      #   - GAM:    the gam() wrapper materializes client_secrets.json +
      #             oauth2service.json from 1Password on first use.
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
