{ lib }:
let
  inherit (lib) mkOption types;
in
{
  mkOpt' =
    type: default: description:
    mkOption { inherit type default description; };
  mkBoolOpt =
    default: description:
    mkOption {
      inherit default description;
      type = types.bool;
      example = true;
    };
}
