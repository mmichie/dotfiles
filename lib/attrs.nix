{ lib }:
with lib;
{
  # Filter and map an attrset simultaneously.
  mapFilterAttrs =
    f: pred: attrs:
    filterAttrs pred (mapAttrs f attrs);

  # Deep merge a list of attrsets. Lists concatenate; scalars: last wins.
  mergeAttrs' =
    attrList:
    let
      f =
        attrPath:
        zipAttrsWith (
          n: values:
          if (tail values) == [ ] then
            head values
          else if all isList values then
            concatLists values
          else if all isAttrs values then
            f (attrPath ++ [ n ]) values
          else
            last values
        );
    in
    f [ ] attrList;
}
