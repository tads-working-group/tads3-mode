# tads3-mode

This TADS 3 emacs mode was modified by Alexis Purslane <alexispurslane@pm.me>
from Brett Witty <brettwitty@brettwitty.net>'s modification of Stephen Granade's
tads2-mode.el to support TADS 3.

## Changes my version adds:

- syntax highlighting for properties when they're being accessed using dot
  notation
- syntax highlighting for properties and variables when they're being set
- syntax highlighting for function and method names when they're being called or
  defined
- different syntax highlighting for double-quoted description strings than
  regular single quoted strings
- syntax highlighting for substitutions inside strings (only inside the strings,
  too, using Emacs' anchored highlighters) and are a different font (italic sans
  serif)
- syntax higlighting for class names (just based on whether it's an identifier
  that starts with an uppercase letter)
- syntax highlighting for numbers
- Some updates to make it compatible with versions of Emacs since v24 (it was
  erroring out)
- Clearer specification of what something is in the imenu list of objects,
  functions, modifications, etc.

## Roadmap

### To finish v1.4
- [ ] Compilation, Error-checking and jump-to-error
- [ ] Add source file to t3m
- [ ] Running the game in editor and refreshing it on build
- [ ] Running test scripts
- [ ] Spellcheck that knows how to deal with TADS text
- [ ] Word count that understands TADS text
- [ ] Strings viewer (the compiler can output all strings)
- [ ] Uploading the plugin to MELPA

### For 2.0

- [ ] Autocompletetion
- [ ] Refactoring tools
- [ ] Documentation for thing at point

## Old Problems
- Multiline C-style comments like:
   /* This
      is
      a comment */
still have font-lock problems. Multiline font-locking is known to
be difficult.
- In such comments, an apostrophe (') will try to match with
something nonsense later on.
- You cannot move to sub-objects via tads-next-object.

## Screenshots

![](./screenshot1.png)
![](./screenshot2.png)
![](./screenshot3.png)

## Installation

Installation is simple. `git clone` this repository somewhere in your load path
(somewhere under `~/.emacs.d/`) or add wherever you put it to your load path,
and then add this code to your configuration file (`init.el`, `config.el` under
DOOM, etc.):

```emacs-lisp
(autoload 'tads3-mode "tads3" "TADS 3 editing mode." t)
(setq auto-mode-alist
      (append (list (cons "\\.t$" 'tads3-mode))
              auto-mode-alist))
```

It's recommended that you also use a soft word wrap mode like `+word-wrap-mode`
with this plugin, since you'll be writing lots of long lines of text.