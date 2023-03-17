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

## New Problems:
- Currently, braces on a newline after a method definition are not properly
  indented
- I had to remove the feature of automatically adding newlines *before* braces
  for those who prefer that, since the feature was very buggy and I'm new to
  writing Emacs plugins

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

It is VERY strongly recommended that swapq-fill.el is used in
conjunction with this mode, to assist in single quote filling.

## Screenshots

![](./screenshot1.png)
![](./screenshot2.png)
![](./screenshot3.png)