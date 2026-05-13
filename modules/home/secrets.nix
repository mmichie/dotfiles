{ config, ... }:
{
  sops = {
    age = {
      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      generateKey = false;
    };

    defaultSopsFile = ../../secrets/atuin-key;
    validateSopsFiles = true;

    secrets."atuin_key" = {
      format = "binary";
      sopsFile = ../../secrets/atuin-key;
      path = "${config.home.homeDirectory}/.local/share/atuin/key";
      mode = "0400";
    };

    secrets."atuin_session" = {
      format = "binary";
      sopsFile = ../../secrets/atuin-session;
      path = "${config.home.homeDirectory}/.local/share/atuin/session";
      mode = "0400";
    };
  };
}
