dotfiles
========

These are my Linux dotfiles. There are many like them, but these are mine.

Hopefully I don't check in something sensitive here.

Install Instructions
===================

These are intended to be used with GNU Stow.  Once you clone the dotfiles repo,
don't forget to run:

```git submodule update --init --recursive```

To initialize all the submodules.  Then for example to install the vim dotfiles
do:

```stow vim -t ~```

See Also
========

  * https://github.com/xero/dotfiles
  * https://github.com/r00k
  * https://github.com/tpope/tpope
  * https://github.com/benbernard/HomeDir
