;;; tads3-mode.el --- TADS 3 mode for GNU Emacs v28.1

;;;;;;;;;;;
;; This version was modified by Brett Witty <brettwitty@brettwitty.net>
;; from Stephen Granade's tads2-mode.el. The only real changes was a
;; modified regexp to deal with object definitions so that
;; tads3-next-object and tads3-prev-object work nicer. It also helps
;; with indenting TADS 3-style object code.
;;
;; Remaining problems:
;; - Multiline C-style comments like:
;;    /* This
;;       is
;;       a comment */
;; still have font-lock problems. Multiline font-locking is known to
;; be difficult.
;; - In such comments, an apostrophe (') will try to match with
;; something nonsense later on.
;; - You cannot move to sub-objects via tads3-next-object.
;;
;; It is VERY strongly recommended that swapq-fill.el is used in
;; conjunction with this mode, to assist in single quote filling.
;;;;;;;;;;;

;; Author: Alexis Purslane <alexispurslane@pm.me>
;; Modified 17 Mar 2023
;; Version 1.4
;; Package-Requires: ((emacs "28.1"))
;; Keywords: languages, tads, text-adventure, interactive-fiction

;; Previous version:
;; Author: Brett Witty <brettwitty@brettwitty.net>
;; Modified: 4 Feb 2006
;; Version: 1.3
;; Keywords: languages

;; Previous version:
;; Author: Stephen Granade <sgranade@phy.duke.edu>
;; Created: 3 Apr 1999
;; Version: 1.2
;; Keywords: languages

;; LCD Archive Entry:
;; tads3-mode|Brett Witty|brettwitty@brettwitty.net|
;; Major mode for editing TADS 3/3 programs|
;; 4-Feb-2006|1.3|~/modes/tads3-mode.el.Z|

;;; Copyright:

;; Portions of this code are Copyright (c) by Stephen Granade 1999. Other
;; portions of this code are Copyright (c) by Brett Witty 2006. Other portions
;; are Copyright (c) by Alexis Purslane 2023. Portions of this code were adapted
;; from GNU Emacs C-mode, and are copyright (c) 1985, 1986, 1987, 1992 by Free
;; Software Foundation, Inc. Other portions of this code were adapted from an
;; earlier TADS mode by Darin Johnson, and are copyright (c) 1994 by Darin
;; Johnson.
;;
;; tads3-mode is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; tads3-mode is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;;; Commentary for version 1.4:

;; This version has been further improved for TADS 3, including more syntax
;; highlighting for various constructions such as function calls, properties,
;; classes, and so on, as well as adding in many keywords that were forgotten
;; the first time around. Additionally, the plugin has been updated to be
;; compatible with Emacs versions past 24, and updated to use more modern Emacs
;; Lisp constructions that were introduced after that version as well. On top of
;; that, several bugfixes have been provided.
;;
;; Thanks to Brett Witty for making the plugin this is based off! I would have
;; never had the courage to start on my own.

;;; Commentary for version 1.3:

;; This version is a modification on the original TADS 3 mode. It can
;; be used for both TADS 3 and 3.
;; TADS 3 can be found at http://www.ifarchive.org/indexes/if-archiveXprogrammingXtads2.html
;; TADS 3 can be found at http://www.ifarchive.org/indexes/if-archiveXprogrammingXtads3.html
;;
;; Thanks to Stephen Granade for the original version, and all those
;; who assisted in its creation.

;;; Commentary for version 1.2:

;; TADS is an adventure programming language which can be found via
;; anonymous FTP at
;; /ftp.gmd.de:/if-archive/programming/tads/
;;
;; This major mode is based heavily on the standard EMACS C-mode.
;; Type `C-h m' within TADS mode for details.
;;
;;
;; Special thanks to Matthew Amster-Burton and Dan Shiovitz, who tested
;; early versions of this mode, and to Dan Schmidt, who got filled
;; strings and imenu support working.
;;

;;; Code:

(eval-when-compile
    (require 'rx))

;;; General variables: --------------------------------------------------------

(defconst tads3-mode-version "1.4")

(defvar tads3-startup-message t
    "*Non-nil means display a message when TADS 3 mode is loaded.")

(defvar tads3-no-c++-comments nil
    "*If t, C++-style comments \(//\) are not fontified or treated as comments.")

(defvar tads3-strip-trailing-whitespace t
    "*If t (the default), delete any trailing whitespace when ENTER is pressed.")

(defvar tads3-mode-abbrev-table nil)

(defvar tads3-mode-map nil
    "Keymap used in TADS 3 mode.")

(if tads3-mode-map nil
    (setq tads3-mode-map (make-sparse-keymap))

    ;; major mode commands
    (define-key tads3-mode-map (kbd "M-n") 'tads3-next-object)
    (define-key tads3-mode-map (kbd "M-p") 'tads3-prev-object)
    (define-key tads3-mode-map (kbd "M-t") 'tads3-inside-block-comment)
    (define-key tads3-mode-map (kbd "C-c C-c") 'tads3-build)
    (define-key tads3-mode-map (kbd "C-c C-1") 'tads3-run)
    (define-key tads3-mode-map (kbd "<f5>") 'tads3-build)
    (define-key tads3-mode-map (kbd "<f4>") 'tads3-run)

    ;; Electric keys
    (define-key tads3-mode-map "{" 'electric-tads3-brace)
    (define-key tads3-mode-map ";" 'electric-tads3-semi)
    (define-key tads3-mode-map "#" 'electric-tads3-sharp-sign)
    (define-key tads3-mode-map "*" 'electric-tads3-splat)
    (define-key tads3-mode-map "\t" 'tads3-indent-command)
    (define-key tads3-mode-map "\r" 'electric-tads3-enter))

(defvar tads3-install-path
    "/usr/local/bin/"
    "The location where the frob interpreter and the TADS 3 compiler reside.")

(defvar tads3-interpreter
    "/usr/local/bin/qtads"
    "The executable for tads3-mode to launch when you run your game.

QTADS is recommended for full freature support, but frobTADS and Gargoyle will also work if you are writing a text only game.")

;;; Indentation parameters: ---------------------------------------------------

(defvar tads3-indent-level 4
    "*Indentation of lines of block relative to first line of block.")

(defvar tads3-label-offset -2
    "*Indentation of label relative to where it should be.")

(defvar tads3-indent-continued-string t
    "*If t (the default), strings continued from the previous line
are indented.")

(defvar tads3-continued-string-offset 1
    "*How much to indent continued strings by compared to the first line
of the string. This is only used if `tads3-indent-continued-string' is
true.")

(defvar tads3-continued-string-offset-from-line 2
    "*How much to indent continued strings by compared to the first line
of the command containing the string, if that command is not purely
the string itself. This is only used if `tads3-indent-continued-string'
is false.")

(defvar tads3-brace-imaginary-offset 0
    "*Imagined indentation of a TADS open brace that actually follows a statement.")

(defvar tads3-brace-offset 0
    "*Extra indentation of braces compared to other text in the same context.")

(defvar tads3-continued-statement-offset 4
    "*Extra indentation for lines which do not begin new statements.")

(defvar tads3-continued-brace-offset -4
    "*Extra indentation for substatements which begin with an open brace.
This is in addition to `tads3-continued-statement-offset'.")

(defvar tads3-indent-cont-statement 4
    "*Indentation of continuation relative to start of statement.")

(defvar tads3-auto-indent-after-newline t
    "*If t (the default), automatically indent the next line after
RETURN is pressed.")

(defvar tads3-tab-always-indent t
    "*If t (the default), always indent the current line when tab is pressed.")

;; I don't know how to fix the original version which also inserts newlines
;; before and after the braces when enabled. - AP
(defvar tads3-auto-newline t
    "*If t, automatically add after semicolons and before braces that
are on the same line as other code in TADS code.")

(defvar tads3--locate-t3m-regexp "\\.t3m$"
  "*Regexp for locating t3make files in parent directories.")

(defvar tads3--locate-t3-regexp "\\.t3$"
  "*Regexp for locating t3 game files in parent directories.")

;;; Syntax variables: ---------------------------------------------------------

(defvar tads3-mode-syntax-table nil
    "Syntax table used in TADS mode.")

(if tads3-mode-syntax-table
    nil
    (setq tads3-mode-syntax-table (make-syntax-table))
    (modify-syntax-entry ?\\ "\\" tads3-mode-syntax-table)
    (modify-syntax-entry ?/ ". 14" tads3-mode-syntax-table)
    (modify-syntax-entry ?* ". 23" tads3-mode-syntax-table)
    (modify-syntax-entry ?+ "." tads3-mode-syntax-table)
    (modify-syntax-entry ?- "." tads3-mode-syntax-table)
    (modify-syntax-entry ?= "." tads3-mode-syntax-table)
    (modify-syntax-entry ?% "." tads3-mode-syntax-table)
    (modify-syntax-entry ?< "." tads3-mode-syntax-table)
    (modify-syntax-entry ?> "." tads3-mode-syntax-table)
    (modify-syntax-entry ?& "." tads3-mode-syntax-table)
    (modify-syntax-entry ?| "." tads3-mode-syntax-table)
    (modify-syntax-entry ?\" "\"" tads3-mode-syntax-table)
    (modify-syntax-entry ?\' "\'" tads3-mode-syntax-table)
    ;; any reason NOT to have _ as a word constituent?  Makes things simpler.
    (modify-syntax-entry ?_ "w" tads3-mode-syntax-table)
    ;; C++ style comments
    (if tads3-no-c++-comments
        ()
        (modify-syntax-entry ?/ ". 124" tads3-mode-syntax-table)
        (modify-syntax-entry ?* ". 23b" tads3-mode-syntax-table)
        (modify-syntax-entry ?\n ">" tads3-mode-syntax-table)))

                                        ;(defvar tads-functions-list
                                        ;  '("addword" "askdo" "askfile" "askio" "caps" "car" "cdr"
                                        ;    "clearscreen" "cvtnum" "cvtstr" "datatype" "defined" "delword"
                                        ;    "endTurn" "execCommand" "fclose" "find" "firstobj" "firstsc" "fopen"
                                        ;    "fseek" "fseekof" "fwrite" "getarg" "getfuse" "gettime" "getwords"
                                        ;    "incturn" "input" "inputdialog" "inputevent" "inputkey" "inputline"
                                        ;    "isclass" "length" "logging" "lower" "nextobj" "nocaps" "notify"
                                        ;    "objwords" "outcapture" "parseAskobjIndirect" "parseNounList"
                                        ;    "parserDictLookup" "parserGetMe" "parserGetObj" "parserGetTokTypes"
                                        ;    "parserReplaceCommand" "parserResolveObjects" "parserSetMe"
                                        ;    "parserTokenize" "postAction" "preCommand" "proptype" "quit" "rand"
                                        ;    "randomize" "reGetGroup" "remdaemon" "remfuse" "reSearch"
                                        ;    "resourceExists" "restart" "restore" "rundaemons" "runfuses" "save"
                                        ;    "say" "setdaemon" "setfuse" "setit" "setOutputFilter" "setscore"
                                        ;    "setversion" "skipturn" "substr" "systemInfo" "timeDelay" "undo"
                                        ;    "unnotify" "upper" "verbInfo" "yorn")
                                        ;  "List of TADS built-in functions.")

;; A function to aid my own failing memory of how to print objects
                                        ;(defun tads-make-regexp ()
                                        ;  (interactive)
                                        ;  (insert (make-regexp tads3-functions-list)))

                                        ;(defvar tads-keywords-list
                                        ;  '("abort" "argcount" "break" "continue" "delete" "do" "else" "exit"
                                        ;    "exitobj" "for" "goto" "if" "inherited" "local" "modify" "new" "nil"
                                        ;    "pass" "replace" "return" "self" "switch" "true" "while")
                                        ;  "List of TADS keywords.")

;; The following regexps were made from the above commented lists using
;; Simon Marshall's make-regexp package (thanks, Gareth!).

(eval-and-compile

    (defvar tads3-functions-regexp
        "\\<\\(a\\(ddword\\|sk\\(do\\|file\\|io\\)\\)\\|c\\(a\\(ps\\|r\\)\\|dr\\|learscreen\\|vt\\(num\\|str\\)\\)\\|d\\(atatype\\|e\\(fined\\|lword\\)\\)\\|e\\(ndTurn\\|xecCommand\\)\\|f\\(close\\|i\\(nd\\|rst\\(obj\\|sc\\)\\)\\|open\\|seek\\(\\|of\\)\\|write\\)\\|get\\(arg\\|fuse\\|time\\|words\\)\\|i\\(n\\(cturn\\|put\\(\\|dialog\\|event\\|key\\|line\\)\\)\\|sclass\\)\\|l\\(ength\\|o\\(gging\\|wer\\)\\)\\|n\\(extobj\\|o\\(caps\\|tify\\)\\)\\|o\\(bjwords\\|utcapture\\)\\|p\\(arse\\(AskobjIndirect\\|NounList\\|r\\(DictLookup\\|Get\\(Me\\|Obj\\|TokTypes\\)\\|Re\\(placeCommand\\|solveObjects\\)\\|SetMe\\|Tokenize\\)\\)\\|ostAction\\|r\\(eCommand\\|optype\\)\\)\\|quit\\|r\\(and\\(\\|omize\\)\\|e\\(GetGroup\\|Search\\|m\\(daemon\\|fuse\\)\\|s\\(ourceExists\\|t\\(art\\|ore\\)\\)\\)\\|un\\(daemons\\|fuses\\)\\)\\|s\\(a\\(ve\\|y\\)\\|et\\(OutputFilter\\|daemon\\|fuse\\|it\\|score\\|version\\)\\|kipturn\\|ubstr\\|ystemInfo\\)\\|timeDelay\\|u\\(n\\(do\\|notify\\)\\|pper\\)\\|verbInfo\\|yorn\\)\\>"
        "Regular expression matching a TADS function")

    ;; (MODIFIED BY AP)
    ;; Class is a keyword. That was somehow missed.
    (defvar tads3-keywords-regexp
        "\\<\\(a\\(bort\\|rgcount\\)\\|break\\|c\\(ontinue\\|lass\\|ase\\)\\|d\\(elete\\|o\\)\\|e\\(lse\\|num\\|xit\\(\\|obj\\)\\)\\|f\\(or\\|unction\\)\\|goto\\|i\\(f\\|nherited\\)\\|local\\|modify\\|n\\(ew\\|il\\)\\|pass\\|re\\(place\\|turn\\)\\|s\\(elf\\|witch\\)\\|t\\(rue\\|ry\\|emplate\\)\\|while\\|static\\|finally\\)\\>"
        "Regular expression matching a TADS reserved word"))

;; A note: tads3-label-regexp and tads3-modified-regexp will NOT match
;; function definitions with returns between the label name and colon, like
;; bedroom_door
;;             : doorway
;; I don't know of anyone who uses this syntax, but someone might. If you
;; do, remove the '\n' from tads3-label-regexp and tads3-modified-regexp.

;; Regexp for finding a label or class name followed by a colon
;; Note that this should *not* match "default:", nor should it match
;; ":=" (for those of you still using the Pascal-style assignment operator)
(defvar tads3-label-regexp "^[ \t]*\\(class \\)?\\([^:;\"!*(\n ]+ *\\):\\($\\|[^=]\\)")

;; Regexp for finding a modified object
(defvar tads3-modified-regexp "^[ \t]*\\(modify\\|replace\\)\\s-+\\([^:;\"!*(\n ]+\\)")

;; Regexp for some TADS special words
(defvar tads3-specials-regexp
    "^[ \t]*\\(compoundWord\\b\\|formatstring\\b\\|specialWords\\b\\)")

;; (MODIFIED BY BW)
;; (Godawful) Regexp for TADS 3 objects, including anonymous
;; ones. This helps the next/previous object commands.
;; This regexp covers all sorts of objects like:
;;
;; (a class)
;; class Something : Class1, Class2
;;
;; (a standard named object)
;; something : Class1
;;
;; (an object using the brace method)
;; something : Class 1 {
;;
;; (an anonymous object)
;; Class1, Class2
;;
;; (any of the above with TADS 3 templates)
;; something : Class1, Class2 'vocab/vocab' 'name' "Description."
;;
;; (anonymous functions)
;; function(arg) { stuff; }
(defvar tads3-regexp
    "^\\(class \\|\\++\\s-*\\)?\\([a-zA-Z]+\\s-*:\\s-*\\)?\\([a-zA-Z]+,?\\)+\\s-*.*;?$")

;; A combination of the above three regexps
(defvar tads3-defun-regexp
    (concat
        "\\("
                                        ; The below is replaced by the tads3-regexp which covers all that.
                                        ;tads3-label-regexp
                                        ;"\\|"
        tads3-modified-regexp
        "\\|"
        tads3-specials-regexp
        "\\|"
        tads3-regexp
        "\\)"))

;; Regexp used internally to recognize labels in switch statements.
(defconst tads3-switch-label-regexp "\\(case[ \t'/\(][^:]+\\|default[ \t]*\\):")

(defconst tads3-class-name-regexp
    (rx symbol-start upper (zero-or-more alnum) (or upper lower digit)) symbol-end)

(defconst tads3-property-name-regexp
    (rx (or (seq symbol-start (group-n 1 lower (zero-or-more (any "a-z" "A-Z" "_"))) symbol-end " = ")
            (seq "." symbol-start (group-n 1 lower (zero-or-more (any "a-z" "A-Z" "_"))) symbol-end))))

(defconst tads3-number-regexp
    (rx symbol-start
        (or digit (seq "0x" digit))
        (zero-or-more digit)
        (optional (seq "." (one-or-more digit)))
        (optional (seq "E" (or "+" "-") (one-or-more digit)))
        symbol-end))

(defconst tads3-description-regexp (rx "\"" (zero-or-more (or "\\\"" (not (any "\"")))) (opt "\"")))
(defconst tads3-substitution-regexp "<<[^>]*\\(?:>>\\)?+")
(defconst tads3-string-regexp (rx "'" (zero-or-more (or "\\'" (not (any "'" "\n" "\r")))) "'"))

(defconst tads3-method-def-regexp "[\t ]*\\(\\_<[a-zA-Z0-9_]+\\_>\\)\\(?:(.*)\\)?\\(?:[\n\t ]*{\\)$")
(defconst tads3-function-call-regexp "\\(?:;\\)?[\t \r]*\\(\\_<[a-zA-Z0-9_]+\\_>\\)([^);]*)\s*;")

;;; Font-lock keywords: -------------------------------------------------------

(defvar tads3-font-lock-defaults
    '(tads3-font-lock-keywords nil nil ((?_ . "w")) tads3-prev-object)
    "Font Lock defaults for TADS mode.")

(defgroup tads3-faces nil
  "Faces used in TADS 3 mode."
  :group 'tads3
  :group 'faces)

(defface tads3-description-face
  '((t . (:inherit font-lock-string-face :weight bold :foreground "#5FAFFF")))
  "Face for Inform 7 strings."
  :group 'tads3-faces)

(defface tads3-substitution-face
  '((t . (:inherit variable-pitch :slant italic :foreground "#3E9EFF")))
  "Face for TADS 3 substitutions embedded in text."
  :group 'tads3-faces)

(defface tads3-single-quote-substitution-face
  '((t . (:inherit variable-pitch :slant italic :foreground "#FDF4E5")))
  "face for TADS 3 substitutions embedded in text."
  :group 'tads3-faces)

(defun tads3-match-inside (outer matcher facespec)
    "Match inside the match OUTER with MATCHER, fontifying with FACESPEC."
    (let ((preform `(progn
                        (goto-char (match-beginning 0))
                        (match-end 0))))
        `(,outer . '(,matcher ,preform nil (0 ,facespec t)))))

(defvar tads3-font-lock-keywords
    (eval-when-compile
        `(
             ;; preprocessor directives as comments.
             ("^#[ \t]*[a-z]+" . 'font-lock-comment-face)
             ("^#[ \t]*include[ \t]+\\(<[^>\"\n]+>\\)"
                 1 'font-lock-string-face)

             ;; objects and non-TADS functions
             ("^\\(\\w+[ \t]+\\)*\\+*[ \t]*\\(\\w+\\) *: *\\w+"
                 2 'font-lock-function-name-face)
             ("^[ \t]*modify \\(\\w+\\)"
                 1 'font-lock-function-name-face)

             ;; TADS keywords.
             (,(concat "\\(" tads3-keywords-regexp "\\)") 0 'font-lock-keyword-face)

             ;; TADS functions.
             (,(concat "\\(" tads3-functions-regexp "\\)") . 'font-lock-builtin-face)

             ;; method def or function call
             (,tads3-function-call-regexp 1 'font-lock-function-name-face)
             (,tads3-method-def-regexp 1 'font-lock-function-name-face)

             ;; TADS class names.
             (,tads3-class-name-regexp . 'font-lock-type-face)

             ;; TADS property set or get
             (,tads3-property-name-regexp 1 'font-lock-variable-name-face)

             ;; Integers and bignums
             (,tads3-number-regexp . 'font-lock-constant-face)

             ;; Single quoted strings
             (,tads3-string-regexp 0 'font-lock-string-face t)
             ,(tads3-match-inside tads3-string-regexp tads3-substitution-regexp `'tads3-single-quote-substitution-face)

             ;; Double quoted strings
             (,tads3-description-regexp 0 'tads3-description-face t)
             ,(tads3-match-inside tads3-description-regexp tads3-substitution-regexp `'tads3-substitution-face)
             ))
    "Expressions to fontify in TADS mode.")


;;; TADS mode: ----------------------------------------------------------------

(defun tads3-mode ()
    "Major mode for editing TADS programs.

* TADS syntax:

  Type \\[indent-for-tab-command] to indent the current line.
  Type \\[indent-region] to indent the region.

* Navigating in a file:

  Type \\[tads3-prev-object] to go to the previous object/class declaration.
  Type \\[tads3-next-object] to go to the next one.

* Font-lock support:

  Put \(add-hook 'tads3-mode-hook 'turn-on-font-lock) in your .emacs file.

*Key definitions:

\\{tads3-mode-map}
* Miscellaneous user options:

  tads3-startup-message
    Set to nil to inhibit the message printed the first time TADS
    mode is used.

  tads3-auto-newline
    If true, automatically insert a newline before and after
    braces, and after colons and semicolons.

  tads3-no-c++-comments
    Set to true to not treat C++-style comments \(//\) as comments.

  tads3-strip-trailing-whitespace
    If true (the default), all whitespace at the end of a line will
    be removed when RETURN is pressed.

  tads3-mode-hook
    The hook that is run after entering TADS mode.

* User options controlling indentation style:

  Values in parentheses are the default indentation style.

  tads3-indent-level \(4\)
    Indentation of code inside an object relative to the first
    line of the block.

  tads3-brace-offset \(0\)
    Extra indentation for a brace as compared to text in the same
    context.

  tads3-brace-imaginary-offset \(0\)
    Imagined indentation for an open brace that follows a statement.

  tads3-indent-cont-statement \(4\)
    Indentation of continuation relative to start of statement.

  tads3-continued-statement-offset \(4\)
    Extra indentation for lines which do not begin new statements

  tads3-continued-brace-offset \(-4\)
    Extra indentation for substatements which start with an open brace.
    This is in addition to `tads3-continued-statement-offset'.

  tads3-label-offset \(-2\)
    Extra indentation for line that is a label, or case or default.

  tads3-indent-continued-string \(t\)
    If true, strings which span more than one line are all indented
    the same amount.

  tads3-continued-string-offset \(1\)
    How much to indent continued strings by compared to the first line
    of the string. This is only used if `tads3-indent-continued-string'
    is true.

  tads3-continued-string-offset-from-line \(2\)
    How much to indent continued strings by compared to the first line
    of the command containing the string, if that command is not purely
    the string itself. This is only used if `tads3-indent-continued-string'
    is false.

  tads3-auto-indent-after-newline \(t\)
    If true, then pressing RETURN also indents the new line that is
    created.

  tads3-tab-always-indents \(t\)
    If true, TAB always indents the current line when pressed.

  tads3-auto-newline \(nil\)
    If true, automatically add newlines after semicolons in TADS code."
    (interactive)
    (if tads3-startup-message
        (message "Emacs TADS mode version %s by Alexis Purslane, Brett W, and Stephen Granade."
            tads3-mode-version))
    (kill-all-local-variables)
    (use-local-map tads3-mode-map)
    (setq major-mode 'tads3-mode)
    (setq mode-name "TADS 3")
    (setq local-abbrev-table tads3-mode-abbrev-table)
    (set-syntax-table tads3-mode-syntax-table)

    (setq-local paragraph-start (concat "^$\\|" page-delimiter))
    (setq-local paragraph-separate paragraph-start)
    (setq-local paragraph-ignore-fill-prefix t)
    (setq-local indent-line-function 'tads3-indent-line)
    (setq-local indent-region-function 'tads3-indent-region)
    (setq-local fill-paragraph-function 'tads3-fill-paragraph)
    (setq-local imenu-generic-expression
        tads3-imenu-generic-expression-regexp)
    (setq-local imenu-prev-index-position-function
        'tads3-prev-object)
    (setq-local require-final-newline t)
    ;; The block mode comments are default
    (setq-local comment-start "/* ")
    (setq-local comment-end " */")
    (setq-local comment-column 40)
    (setq-local comment-start-skip "/\\*+ *\\|// *")
    (setq-local comment-indent-function 'tads3-comment-indent)
    (setq-local parse-sexp-ignore-comments t)
    (setq-local font-lock-defaults tads3-font-lock-defaults)
    (run-hooks 'tads3-mode-hook))

;; This is used by indent-for-comment
;; to decide how much to indent a comment in C code
;; based on its context.
(defun tads3-comment-indent ()
    (if (looking-at "^\\(/\\*\\|//\\)")
        0				;Existing comment at bol stays there.
        (let ((opoint (point)))
            (save-excursion
                (beginning-of-line)
                (cond ((looking-at "[ \t]*}[ \t]*\\($\\|/\\*\\|//\\)")
                          ;; A comment following a solitary close-brace
                          ;; should have only one space.
                          (search-forward "}")
                          (1+ (current-column)))
                    ((or (looking-at "^#[ \t]*endif[ \t]*")
                         (looking-at "^#[ \t]*else[ \t]*"))
                        7)              ;2 spaces after #endif
                    ((progn
                         (goto-char opoint)
                         (skip-chars-backward " \t")
                         (and (= comment-column 0) (bolp)))
                        ;; If comment-column is 0, and nothing but space
                        ;; before the comment, align it at 0 rather than 1.
                        0)
                    (t
                        (max (1+ (current-column)) ;Else indent at comment column
                            comment-column)))))))   ; except leave at least one space.

(defun tads3-indent-command (&optional whole-exp)
    "Indent current line as TADS code, or in some cases insert a tab character."
    (interactive "P")
    (if whole-exp
        ;; If arg, always indent this line as TADS
        ;; and shift remaining lines of expression the same amount.
        (let ((shift-amt (tads3-indent-line))
                 beg end)
            (save-excursion
                (if tads3-tab-always-indent
                    (beginning-of-line))
                ;; Find beginning of following line.
                (save-excursion
                    (forward-line 1) (setq beg (point)))
                ;; Find first beginning-of-sexp for sexp extending past this line.
                (while (< (point) beg)
                    (forward-sexp 1)
                    (setq end (point))
                    (skip-chars-forward " \t\n")))
            (if (> end beg)
                (indent-code-rigidly beg end shift-amt "#")))
        ;; else just indent the one line
        (if (and (not tads3-tab-always-indent)
                (save-excursion
                    (skip-chars-backward " \t")
                    (not (bolp))))
            (insert-tab)
            (tads3-indent-line))))

(defun tads3-indent-region (start end)
    (save-restriction
        (let ((endline (progn (goto-char (max end start))
                           (or (bolp) (end-of-line))
                           (point)))
                 linestart)
            (narrow-to-region (point-min) endline)
            (goto-char (min start end))
            (forward-line 0)
            (while (not (eobp))
                (tads3-indent-line)
                (forward-line 1)))))

(defun tads3-non-indented-string-indentation ()
    "Return indentation for the current string."
    (save-excursion
        (let ((start (1+ (re-search-backward "[^\\]\""))))
            (goto-char start)
            (+ (current-indentation)
                (if (progn (skip-chars-backward " \t")
                        (bolp))
                    0
                    tads3-continued-string-offset-from-line)))))

(defun tads3-indent-line ()
    "Indent current line as TADS code. Return the amount the indentation changed by."
    (let ((indent (calculate-tads3-indent nil))
             beg shift-amt
             (case-fold-search nil)
             (pos (- (point-max) (point))))
        (beginning-of-line)
        (setq beg (point))
        (cond ((eq indent nil)
                  ;; string
                  (setq indent
                      (calculate-tads3-indent-within-string)))
            ((eq indent t)
                ;; comment
                (setq indent (calculate-tads3-indent-within-comment)))
            ((looking-at "[ \t]*#")
                ;; directive
                (setq indent 0))
            ((and (not (looking-at "[ \t]*;"))
                 (save-excursion
                     (tads3-backward-to-noncomment 1)
                     (backward-char)
                     (looking-at "\"")))
                ;; "description"
                (setq indent tads3-indent-level))
            (t
                (if (listp indent)
                    (setq indent (car indent))
                    ;; Check special cases (don't do this if indent was a list,
                    ;; since that means we were at the top level, and these
                    ;; cases are only for C-style code)
                    (skip-chars-forward " \t")
                    (cond ((or (looking-at tads3-switch-label-regexp)
                               (and (looking-at "[A-Za-z]")
                                   (save-excursion
                                       (forward-sexp 1)
                                       (looking-at ":"))))
                              (setq indent (max 1 (+ indent tads3-label-offset))))
                        ((and (looking-at "else\\b")
                             (not (looking-at "else\\s_")))
                            (setq indent (save-excursion
                                             (tads3-backward-to-start-of-if)
                                             (current-indentation))))
                        ((and (looking-at "}[ \t]*else\\b")
                             (not (looking-at "}[ \t]*else\\s_")))
                            (setq indent (save-excursion
                                             (forward-char)
                                             (backward-sexp)
                                             (tads3-backward-to-start-of-if)
                                             (current-indentation))))
                        ((and (looking-at "while\\b")
                             (not (looking-at "while\\s_"))
                             (save-excursion
                                 (tads3-backward-to-start-of-do)))
                            ;; This is a `while' that ends a do-while.
                            (setq indent (save-excursion
                                             (tads3-backward-to-start-of-do)
                                             (current-indentation))))
                        ((= (following-char) ?})
                            (setq indent (- indent tads3-indent-level)))
                        ((= (following-char) ?{)
                            (setq indent (+ indent tads3-brace-offset)))))))
        (skip-chars-forward " \t")
        (setq shift-amt (- indent (current-column)))
        (if (zerop shift-amt)
            (if (> (- (point-max) pos) (point))
                (goto-char (- (point-max) pos)))
            (delete-region beg (point))
            (indent-to indent)
            ;; If initial point was within line's indentation,
            ;; position after the indentation.  Else stay at same point in text.
            (if (> (- (point-max) pos) (point))
                (goto-char (- (point-max) pos))))
        shift-amt))

;; quite different from the C-mode version
(defun calculate-tads3-indent (&optional parse-start)
    "Return appropriate indentation for current line as TADS code.
In usual case returns an integer: the column to indent to.
Returns nil if line starts inside a string, t if in a comment.
If indent is returned inside a list, this means we are at the top
level rather than being C-style code in a function body."
    (save-excursion
        (beginning-of-line)
        (let ((indent-point (point))
                 (case-fold-search nil)
                 state
                 containing-sexp
                 next-char)
            (if parse-start
                (goto-char parse-start)
                (tads3-beginning-of-defun)
                (setq parse-start (point)))
            (while (< (point) indent-point)
                (setq parse-start (point))
                (setq state (parse-partial-sexp (point) indent-point 0))
                (setq containing-sexp (car (cdr state))))
            ;; Now we've got some info, figure out what's up
            ;; State is: (paren-depth inner-list-start last-sexp instring incomment
            ;;            after-quote min-paren-depth)
            (cond
                ((or (nth 3 state) (nth 4 state))
                    ;; Comment or string
                    (nth 4 state))
                ((null containing-sexp)
                    ;; We're at the top level.
                    (goto-char indent-point)
                    (skip-chars-forward " \t")
                    ;; returning a list, to flag us as top-level
                    (setq next-char (following-char))
                    (list
                        (cond ((or (= next-char ?\;) ; end of object def
                                   (tads3-looking-at-defun))
                                  0)
                            ((progn
                                 (tads3-backward-to-noncomment parse-start)
                                 (= (preceding-char) ?=)) ; continued property def
                                (+ (current-indentation)
                                    (if (= next-char ?{)
                                        0		; starting a method
                                        tads3-continued-statement-offset))) ; continued propy
                            ;; check for start of function def (already checked
                            ;; if we're a continued property def)
                            ((= next-char ?{)
                                (current-indentation))			; start of function body
                            ((and (= (current-indentation) 0)
                                 (memq (preceding-char) '(?\; ?})))
                                ;; just after obj def or func def
                                0)
                            ((save-excursion
                                 (beginning-of-line)
                                 (tads3-looking-at-defun)) ; first line after def'n
                                tads3-indent-level)
                            (t
                                ;; Normal, non continued line (we hope)
                                ;; so use indentation of prev line (watching out
                                ;; for things that could span multiple lines)
                                (if (memq (preceding-char) '(?\} ?\" ?\'))
                                    (progn
                                        (backward-sexp 1)
                                        (skip-chars-backward " \t\n")))
                                (current-indentation)))))

                ;; Not at top level - so we go back to doing C stuff
                ((/= (char-after containing-sexp) ?{)
                    ;; line is expression, not statement (i.e., we're
                    ;; inside parens or square brackets, not curlies),
                    ;; indent to just after the surrounding open.
                    (goto-char (1+ containing-sexp))
                    (current-column))
                (t
                    ;; We're part of a statement.  Continuation or new statement?
                    ;; Find previous non-comment character.
                    (goto-char indent-point)
                    (tads3-backward-to-noncomment containing-sexp)
                    (if (not (memq (preceding-char) '(nil ?\, ?\; ?} ?: ?\{)))
                        ;; This line is continuation of preceding line's statement;
                        ;; indent  tads3-continued-statement-offset  more than the
                        ;; previous line of the statement.
                        (progn
                            (tads3-backward-to-start-of-continued-exp containing-sexp)
                            (+ tads3-continued-statement-offset (current-column)
                                (if (save-excursion (goto-char indent-point)
                                        (skip-chars-forward " \t")
                                        (eq (following-char) ?{))
                                    tads3-continued-brace-offset 0)))
                        ;; This line starts a new statement.
                        ;; Position following last unclosed open.
                        (goto-char containing-sexp)
                        ;; Is line first statement after an open-brace?
                        (or
                            ;; If no, find that first statement and indent like it.
                            (save-excursion
                                (forward-char 1)
                                (while (progn (skip-chars-forward " \t\n")
                                           (looking-at
                                               (concat
                                                   "#\\|/\\*\\|//"
                                                   "\\|case[ \t].*:"
                                                   "\\|[a-zA-Z0-9_$]*:")))
                                    ;; Skip over comments and labels following openbrace.
                                    (cond ((= (following-char) ?\#)
                                              (forward-line 1))
                                        ((looking-at "/\\*")
                                            (forward-char 2)
                                            (search-forward "*/" nil 'move))
                                        ((looking-at "//")
                                            (forward-line 1))
                                        (t
                                            (search-forward ":"))))
                                ;; The first following code counts
                                ;; if it is before the line we want to indent.
                                (and (< (point) indent-point)
                                    (current-column)))
                            ;; If no previous statement,
                            ;; indent it relative to line brace is on.
                            ;; For open brace in column zero, don't let statement
                            ;; start there too.  If tads3-indent-offset is zero,
                            ;; use tads3-brace-offset + tads3-continued-statement-offset
                            ;; instead.
                            ;; For open-braces not the first thing in a line,
                            ;; add in tads3-brace-imaginary-offset.
                            (+ (if (and (bolp) (zerop tads3-indent-level))
                                   (+ tads3-brace-offset tads3-continued-statement-offset)
                                   tads3-indent-level)
                                ;; Move back over whitespace before the openbrace.
                                ;; If openbrace is not first nonwhite thing on the line,
                                ;; add the tads3-brace-imaginary-offset.
                                (progn (skip-chars-backward " \t")
                                    (if (bolp) 0 tads3-brace-imaginary-offset))
                                ;; If the openbrace is preceded by a parenthesized exp,
                                ;; move to the beginning of that;
                                ;; possibly a different line
                                (progn
                                    (if (eq (preceding-char) ?\))
                                        (forward-sexp -1))
                                    ;; Get initial indentation of the line we are on.
                                    (current-indentation))))))))))

(defun calculate-tads3-indent-within-comment (&optional after-star)
    "Return the indentation amount for line inside a block comment.
Optional arg AFTER-STAR means, if lines in the comment have a leading star,
return the indentation of the text that would follow this star."
    (let (end star-start two-star)
        (save-excursion
            (beginning-of-line)
            (skip-chars-forward " \t")
            (setq star-start (= (following-char) ?\*)
                two-star (looking-at "\\*\\*"))
            (skip-chars-backward " \t\n")
            (setq end (point))
            (beginning-of-line)
            (skip-chars-forward " \t")
            (if after-star
                (and (looking-at "\\*")
                    (re-search-forward "\\*[ \t]*")))
            (and (re-search-forward "/\\*[ \t]*" end t)
                star-start
                (not after-star)
                (goto-char (1+ (match-beginning 0)))
                (if two-star
                    (backward-char))
                (sit-for 1))
            (if (and (looking-at "[ \t]*$") (= (preceding-char) ?\*))
                (1+ (current-column))
                (current-column)))))

(defun calculate-tads3-indent-within-string ()
    "Return the indentation amount for line inside a string."
    (if (not tads3-indent-continued-string)
        (tads3-non-indented-string-indentation)
        (save-excursion
            (let ((beg-point (point))
                     parse-start)
                (tads3-beginning-of-defun)
                (setq parse-start (point))
                (goto-char beg-point)
                ;; now keep searching backwards until start of string
                ;; (ugly)
                (while (nth 3
                           (parse-partial-sexp parse-start (point) nil))
                    (re-search-backward "\\s\"" nil t))
                (+ (current-column) tads3-continued-string-offset)))))

(defun tads3-backward-to-start-of-continued-exp (lim)
    (if (memq (preceding-char) '(?\) ?\"))
        (forward-sexp -1))
    (beginning-of-line)
    (if (<= (point) lim)
        (goto-char (1+ lim)))
    (skip-chars-forward " \t"))

(defun tads3-backward-to-start-of-if (&optional limit)
    "Move to the start of the last \"unbalanced\" `if'."
    (or limit (setq limit (save-excursion (beginning-of-defun) (point))))
    (let ((if-level 1)
             (case-fold-search nil))
        (while (and (not (bobp)) (not (zerop if-level)))
            (backward-sexp 1)
            (cond ((and (looking-at "else\\b")
                       (not (looking-at "else\\s_")))
                      (setq if-level (1+ if-level)))
                ((and (looking-at "if\\b")
                     (not (looking-at "if\\s_")))
                    (setq if-level (1- if-level)))
                ((< (point) limit)
                    (setq if-level 0)
                    (goto-char limit))))))

(defun tads3-backward-to-start-of-do (&optional limit)
    "If point follows a `do' statement, move to beginning of it and return t.
Otherwise return nil and don't move point."
    (or limit (setq limit (save-excursion (beginning-of-defun) (point))))
    (let ((first t)
             (startpos (point))
             (done nil))
        (while (not done)
            (let ((next-start (point)))
                (condition-case nil
                    ;; Move back one token or one brace or paren group.
                    (backward-sexp 1)
                    ;; If we find an open-brace, we lose.
                    (error (setq done 'fail)))
                (if done
                    nil
                    ;; If we reached a `do', we win.
                    (if (looking-at "do\\b")
                        (setq done 'succeed)
                        ;; Otherwise, if we skipped a semicolon, we lose.
                        ;; (Exception: we can skip one semicolon before getting
                        ;; to a the last token of the statement, unless that token
                        ;; is a close brace.)
                        (if (save-excursion
                                (forward-sexp 1)
                                (or (and (not first) (= (preceding-char) ?}))
                                    (search-forward ";" next-start t
                                        (if (and first
                                                (/= (preceding-char) ?}))
                                            2 1))))
                            (setq done 'fail)
                            (setq first nil)
                            ;; If we go too far back in the buffer, we lose.
                            (if (< (point) limit)
                                (setq done 'fail)))))))
        (if (eq done 'succeed)
            t
            (goto-char startpos)
            nil)))

(defun tads3-beginning-of-defun ()
    (interactive)
    "Move either to what we think is start of TADS function or object, or,
if not found, to the start of the buffer."
    (beginning-of-line)
    (while (not (or (tads3-looking-at-defun) (= (point) (point-min))))
        (and (re-search-backward (concat "^" tads3-defun-regexp) nil 'move)
            (goto-char (match-beginning 0)))))

(defun tads3-backward-to-noncomment (lim)
    (let (opoint stop)
        (while (not stop)
            (skip-chars-backward " \t\n\r\f" lim)
            (setq opoint (point))
            (cond ((and (>= (point) (+ 2 lim))
                       (save-excursion
                           (forward-char -2)
                           (looking-at "\\*/")))
                      (search-backward "/*" lim 'move))
                ((search-backward "//" (max lim (save-excursion
                                                    (beginning-of-line)
                                                    (point)))
                     'move))
                (t (beginning-of-line)
                    (skip-chars-forward " \t")
                    (if (looking-at "#")
                        (setq stop (<= (point) lim))
                        (setq stop t)
                        (goto-char opoint)))))))

;; tells if we're at top level (or inside braces)
(defun tads3-top-level ()
    (save-excursion
        (beginning-of-line)
        (let ((opoint (point))
                 state)
            (tads3-beginning-of-defun)
            (while (< (point) opoint)
                (setq state (parse-partial-sexp (point) opoint 0)))
            (null (car (cdr state))))))

;; fill a comment or a string
(defun tads3-fill-paragraph (&optional arg)
    "Like \\[fill-paragraph] but handle C comments.
If any of the current line is a comment or within a comment,
fill the comment or the paragraph of it that point is in,
preserving the comment indentation or line-starting decorations."
    (interactive "P")
    (let* (comment-start-place
              (first-line
                  ;; Check for obvious entry to comment.
                  (save-excursion
                      (beginning-of-line)
                      (skip-chars-forward " \t\n")
                      (and (looking-at comment-start-skip)
                          (setq comment-start-place (point))))))
        (if (save-excursion
                (beginning-of-line)
                (looking-at ".*//")) ;; handle c++-style comments
            (let (fill-prefix
                     (paragraph-start
                         ;; Lines containing just a comment start or just an end
                         ;; should not be filled into paragraphs they are next to.
                         (concat
                             paragraph-start
                             "\\|[ \t]*/\\*[ \t]*$\\|[ \t]*\\*/[ \t]*$\\|[ \t/*]*$"))
                     (paragraph-separate
                         (concat
                             paragraph-separate
                             "\\|[ \t]*/\\*[ \t]*$\\|[ \t]*\\*/[ \t]*$\\|[ \t/*]*$")))
                (save-excursion
                    (beginning-of-line)
                    ;; Move up to first line of this comment.
                    (while (and (not (bobp)) (looking-at "[ \t]*//"))
                        (forward-line -1))
                    (if (not (looking-at ".*//"))
                        (forward-line 1))
                    ;; Find the comment start in this line.
                    (re-search-forward "[ \t]*//[ \t]*")
                    ;; Set the fill-prefix to be what all lines except the first
                    ;; should start with.
                    (let ((endcol (current-column)))
                        (skip-chars-backward " \t")
                        (setq fill-prefix
                            (concat (make-string (- (current-column) 2) ?\ )
                                "//"
                                (make-string (- endcol (current-column)) ?\ ))))
                    (save-restriction
                        ;; Narrow down to just the lines of this comment.
                        (narrow-to-region (point)
                            (save-excursion
                                (forward-line 1)
                                (while (looking-at "[ \t]*//")
                                    (forward-line 1))
                                (point)))
                        (insert fill-prefix)
                        (fill-paragraph arg)
                        (delete-region (point-min)
                            (+ (point-min) (length fill-prefix))))))
            (if (or first-line
                    ;; t if we enter a comment between start of function and
                    ;; this line.
                    (eq (calculate-tads3-indent) t)
                    ;; t if this line contains a comment starter.
                    (setq first-line
                        (save-excursion
                            (beginning-of-line)
                            (prog1
                                (re-search-forward comment-start-skip
                                    (save-excursion (end-of-line)
                                        (point))
                                    t)
                                (setq comment-start-place (point))))))
                ;; Inside a comment: fill one comment paragraph.
                (let ((fill-prefix
                          ;; The prefix for each line of this paragraph
                          ;; is the appropriate part of the start of this line,
                          ;; up to the column at which text should be indented.
                          (save-excursion
                              (beginning-of-line)
                              (if (looking-at "[ \t]*/\\*.*\\*/")
                                  (progn (re-search-forward comment-start-skip)
                                      (make-string (current-column) ?\ ))
                                  (if first-line (forward-line 1))

                                  (let ((line-width (progn (end-of-line) (current-column))))
                                      (beginning-of-line)
                                      (prog1
                                          (buffer-substring
                                              (point)

                                              ;; How shall we decide where the end of the
                                              ;; fill-prefix is?
                                              ;; calculate-tads3-indent-within-comment
                                              ;; bases its value on the indentation of
                                              ;; previous lines; if they're indented
                                              ;; specially, it could return a column
                                              ;; that's well into the current line's
                                              ;; text.  So we'll take at most that many
                                              ;; space, tab, or * characters, and use
                                              ;; that as our fill prefix.
                                              (let ((max-prefix-end
                                                        (progn
                                                            (move-to-column
                                                                (calculate-tads3-indent-within-comment t)
                                                                t)
                                                            (point))))
                                                  (beginning-of-line)
                                                  (skip-chars-forward " \t*" max-prefix-end)
                                                  ;; Don't include part of comment terminator
                                                  ;; in the fill-prefix.
                                                  (and (eq (following-char) ?/)
                                                      (eq (preceding-char) ?*)
                                                      (backward-char 1))
                                                  (point)))

                                          ;; If the comment is only one line followed
                                          ;; by a blank line, calling move-to-column
                                          ;; above may have added some spaces and tabs
                                          ;; to the end of the line; the fill-paragraph
                                          ;; function will then delete it and the
                                          ;; newline following it, so we'll lose a
                                          ;; blank line when we shouldn't.  So delete
                                          ;; anything move-to-column added to the end
                                          ;; of the line.  We record the line width
                                          ;; instead of the position of the old line
                                          ;; end because move-to-column might break a
                                          ;; tab into spaces, and the new characters
                                          ;; introduced there shouldn't be deleted.

                                          ;; If you can see a better way to do this,
                                          ;; please make the change.  This seems very
                                          ;; messy to me.
                                          (delete-region (progn (move-to-column line-width)
                                                             (point))
                                              (progn (end-of-line) (point))))))))

                         (paragraph-start
                             ;; Lines containing just a comment start or just an end
                             ;; should not be filled into paragraphs they are next to.
                             (concat
                                 paragraph-start
                                 "\\|[ \t]*/\\*[ \t]*$\\|[ \t]*\\*/[ \t]*$\\|[ \t/*]*$"))
                         (paragraph-separate
                             (concat
                                 paragraph-separate
                                 "\\|[ \t]*/\\*[ \t]*$\\|[ \t]*\\*/[ \t]*$\\|[ \t/*]*$"))
                         (chars-to-delete 0))
                    (save-restriction
                        ;; Don't fill the comment together with the code
                        ;; following it.  So temporarily exclude everything
                        ;; before the comment start, and everything after the
                        ;; line where the comment ends.  If comment-start-place
                        ;; is non-nil, the comment starter is there.  Otherwise,
                        ;; point is inside the comment.
                        (narrow-to-region (save-excursion
                                              (if comment-start-place
                                                  (goto-char comment-start-place)
                                                  (search-backward "/*"))
                                              ;; Protect text before the comment start
                                              ;; by excluding it.  Add spaces to bring back
                                              ;; proper indentation of that point.
                                              (let ((column (current-column)))
                                                  (prog1 (point)
                                                      (setq chars-to-delete column)
                                                      (insert-char ?\  column))))
                            (save-excursion
                                (if comment-start-place
                                    (goto-char (+ comment-start-place 2)))
                                (search-forward "*/" nil 'move)
                                (forward-line 1)
                                (point)))
                        (save-excursion
                            (goto-char (point-max))
                            (forward-line -1)
                            ;; And comment terminator was on a separate line before,
                            ;; keep it that way.
                            ;; This also avoids another problem:
                            ;; if the fill-prefix ends in a *, it could eat up
                            ;; the * of the comment terminator.
                            (if (looking-at "[ \t]*\\*/")
                                (narrow-to-region (point-min) (point))))
                        (fill-paragraph arg)
                        (save-excursion
                            ;; Delete the chars we inserted to avoid clobbering
                            ;; the stuff before the comment start.
                            (goto-char (point-min))
                            (if (> chars-to-delete 0)
                                (delete-region (point) (+ (point) chars-to-delete)))
                            ;; Find the comment ender (should be on last line of buffer,
                            ;; given the narrowing) and don't leave it on its own line.
                            ;; Do this with a fill command, so as to preserve sentence
                            ;; boundaries.
                            (goto-char (point-max))
                            (forward-line -1)
                            (search-forward "*/" nil 'move)
                            (beginning-of-line)
                            (if (looking-at "[ \t]*\\*/")
                                (let ((fill-column (+ fill-column 9999)))
                                    (forward-line -1)
                                    (fill-region-as-paragraph (point) (point-max)))))))
                ;; Outside of comments: do ordinary filling.
                (tads3-fill-string-paragraph arg)))
        t))

;; To do : don't kill off double spacing
;;         don't get rid of returns before/after '\n' or '\b'
;;         calculate-tads3-indent can get fooled by backslashes
;;
;; Largely hacked from Gareth Rees' inform-fill-paragraph by
;; Dan Schmidt
;;
(defun tads3-fill-string-paragraph (&optional arg)
    "Fill a string according to our standards for string indentation."
    (interactive "P")
    (let* ((case-fold-search t)
              indent-type)
        (insert ?\n)
        (setq indent-type (calculate-tads3-indent))
        (delete-backward-char 1)
        (if (eq indent-type nil)
            ;; string
            (let* ((indent-col (prog2
                                   (insert ?\n)
                                   (calculate-tads3-indent-within-string)
                                   (delete-backward-char 1)))
                      (start (1+ (re-search-backward "[^\\]\"")))
                      (end (progn (forward-char 1) (re-search-forward "[^\\]\"")))
                      (fill-column (- fill-column 2))
                      linebeg)
                (save-restriction
                    (narrow-to-region (point-min) end)

                    ;; Fold all the lines together, removing multiple spaces
                    ;; as we go.
                    (subst-char-in-region start end ?\n ? )
                    (subst-char-in-region start end ?\t ? )
                    (goto-char start)
                    (while (re-search-forward "  +" end t)
                        (delete-region (match-beginning 0) (1- (match-end 0))))

                    ;; Split this line; reindent after first split,
                    ;; otherwise indent to point where first split ended
                    ;; up.
                    (goto-char start)
                    (setq linebeg start)
                    (while (not (eobp))
                        (move-to-column (1+ fill-column))
                        (if (eobp)
                            nil
                            (skip-chars-backward "^ " linebeg)
                            (if (eq (point) linebeg)
                                (progn
                                    (skip-chars-forward "^ ")
                                    (skip-chars-forward " "))
                                (while (= (preceding-char) ?\ ) ; Get rid of any
                                    (delete-backward-char 1)))    ; trailing spaces
                            (insert ?\n)
                            (indent-to-column indent-col 1)
                            (setq linebeg (point)))))

                ;; Return T so that `fill-paragaph' doesn't try anything.
                t))))


;;; Miscellaneous: ------------------------------------------------------------

(defun tads3-make-project (makefile)
    "Builds the .t3m file given by MAKEFILE for a project.

Since the makefile name/path is the same as the project name, uses that as the project name as well."
    (let ((comp-buffer-name (concat "*compilation*<" makefile ">")))
        (when (get-buffer comp-buffer-name)
            (delete-windows-on (get-buffer comp-buffer-name))
            (kill-buffer comp-buffer-name))
        (compile (concat tads3-install-path "t3make -d -f " makefile))))

;; We assume multiple t3make files, in case there is a webui version and a standard.
(defun tads3-locate-file (&optional regex)
  "Return a list of t3make files in this directory, or the first parent directory that contains any. "
  (let* ((file-regex (or regex tads3--locate-t3m-regexp))
         (this-dir (file-name-directory (buffer-file-name)))
         (t3m-dir (locate-dominating-file this-dir (lambda (dir) (directory-files dir nil file-regex t))))
         (t3m-files (directory-files t3m-dir nil file-regex t)))
    (if (null t3m-files)
        (error "No t3m files found")
      (mapcar (lambda (file) (file-name-concat t3m-dir file) ) t3m-files))))

(defun tads3-add-src-file-to-t3m ()
  "Adds the current file to the project t3make file(s). "
  (interactive)
  (let* ((cur-file (buffer-file-name))
         (cur-file-no-ext (file-name-sans-extension cur-file))
         (src-line (format "-source %s" (file-name-nondirectory cur-file-no-ext)))
         (t3m-files (tads3-locate-file)))
    (dolist (t3m t3m-files)
      (write-region src-line nil t3m 'append))
    (message "Added %s to %s" cur-file (string-join t3m-files ", "))))

(defun tads3-build ()
    "Builds the current project using its .t3m file.

Finds the .t3m file in the current directory, or a parent directory."
    (interactive)
    (let ((t3m-files (tads3-locate-file)))
        (tads3-make-project (if (length> t3m-files 1)
                                (completing-read "Choose t3m file to build: " t3m-files)
                                (car t3m-files)))))

(defvar *tads3-interpreter-process* nil
    "Holds the current running interpreter process.")

(defun tads3-run ()
    "Build and run the project's .t3 game file in the provided interpreter."
    (interactive)
    (let* ((game-files (tads3-locate-file tads3--locate-t3-regexp))
           (game-file (if (length> game-files 1)
                          (completing-read "Choose t3 game file to run: " game-files)
                          (car game-files)))
           (game-buffer-name (concat "*interpreter*<" game-file ">")))
        (when *tads3-interpreter-process*
            (delete-process *tads3-interpreter-process*)
            (setq *tads3-interpreter-process* nil))
        (setq *tads3-interpreter-process* (start-process tads3-interpreter game-buffer-name tads3-interpreter (file-truename game-file)))))

(defun tads3-next-object (&optional arg)
    "Go to the next object or class declaration in the file.
With a prefix arg, go forward that many declarations.
With a negative prefix arg, search backwards."
    (interactive "P")
    (let* ((fun 're-search-forward)
              (errstring "more")
              (n (prefix-numeric-value arg))
              (forward-or-backward (if (< n 0) -1 1))
              (additional-n (if (and (tads3-looking-at-defun)
                                    (not (< n 0))) 1 0))
              success                   ; did re-search-forward actually work?
              flag)
        (if (< n 0)
            (setq fun 're-search-backward errstring "previous" n (- n)))
                                        ; loop until we're looking at a label which is *not* part of a switch
        (while
            (and
                ;; do the actual move, and put the cursor at column 0
                (setq success
                    (prog1
                        (funcall fun tads3-defun-regexp nil 'move (+ n additional-n))
                        (forward-line 0)))
                (looking-at (concat "^[ \t]*" tads3-switch-label-regexp)))
            ;; This was really a switch label, keep going
            (forward-line forward-or-backward)
            (setq additional-n 0))
        ;; Return whether we succeeded
        success))

;; This function doubles as an `imenu-prev-name' function, so when
;; called noninteractively it must return non-NIL if it was successful and
;; NIL if not.  Argument NIL must correspond to moving backwards by 1.

(defun tads3-prev-object (&optional arg)
    "Go to the previous object or class declaration in the file.
With a prefix arg, go back many declarations.
With a negative prefix arg, go forwards."
    (interactive "P")
    (tads3-next-object (- (prefix-numeric-value arg))))

(defvar tads3-imenu-generic-expression-regexp
    (list
        (list (purecopy "Functions") (purecopy "^\\(\\w+\\)\\s-*:\\s-*function\\(;\\)?") 1)
        (list (purecopy "Methods") (purecopy tads3-method-def-regexp) 1)
        (list (purecopy "Objects") (purecopy "^\\(\\w+\\)\\s-*:") 1)
        (list (purecopy "Contained Objects") (purecopy "^\\++\s*\\(\\w+\\)\\s-*:") 1)
        (list (purecopy "Modifications") (purecopy "^\\(modify\\|replace\\)\\s-+\\(\\w+\\)") 2)
        (list (purecopy "Classes") (purecopy "^class\\s-+\\(\\w+\\)\\s-*:") 1)))

(defun tads3-imenu-extract-name ()
    (cond
        ((looking-at "^\\(\\w+\\)\\s-*:\\s-*function\\(;\\)?")
            (if (not (match-string 2)) ; If it's a forward declaration, don't bite
                (concat "Function "
                    (buffer-substring-no-properties (match-beginning 1)
                        (match-end 1)))))
        ((looking-at "^\\(\\w+\\)\\s-*:")
            (concat "Object "
                (buffer-substring-no-properties (match-beginning 1)
                    (match-end 1))))
        ((looking-at )
            (concat "Modification "
                (buffer-substring-no-properties (match-beginning 2)
                    (match-end 2))))
        ((looking-at "^class\\s-+\\(\\w+\\)\\s-*:")
            (concat "Class "
                (buffer-substring-no-properties (match-beginning 1)
                    (match-end 1))))))

(defun tads3-inside-comment ()
    (interactive)
    (save-excursion
        (beginning-of-line)
        (let ((opoint (point))
                 state)
            (tads3-beginning-of-defun)
            (while (< (point) opoint)
                (setq state (parse-partial-sexp (point) opoint)))
            (nth 4 state))))

(defun tads3-inside-parens-p ()
    (condition-case ()
        (save-excursion
            (save-restriction
                (narrow-to-region (point)
                    (progn (beginning-of-defun) (point)))
                (goto-char (point-max))
                (= (char-after (or (scan-lists (point) -1 1) (point-min))) ?\()))
        (error nil)))

;; This function exists because it's very hard to come up with a regexp
;; which means, "match any label except 'default:'".
(defun tads3-looking-at-defun ()
    (and (looking-at tads3-defun-regexp)
        (not (looking-at "[ \t]*default[ \t]*:"))))


;;; Electric commands: --------------------------------------------------------

(defun electric-tads3-brace (arg)
    "Insert character and correct line's indentation."
    (interactive "P")
    (let (insertpos)
        (if (and tads3-auto-newline
                (not (save-excursion
                         (skip-chars-backward " \t")
                         (bolp))))
            (progn
                (tads3-indent-line)
                (newline)))
        (self-insert-command (prefix-numeric-value arg))
        (tads3-indent-line)
        (newline)
        (save-excursion
            (newline)
            (tads3-indent-line))
        (tads3-indent-line)))

(defun electric-tads3-splat (arg)
    "Insert character and correct line's indentation, if in a comment."
    (interactive "P")
    (self-insert-command (prefix-numeric-value arg))
    (if (tads3-inside-comment)
        (tads3-indent-line)))

(defun electric-tads3-sharp-sign (arg)
    "Insert character and correct line's indentation."
    (interactive "P")
    (if (save-excursion
            (skip-chars-backward " \t")
            (bolp))
        (let ((tads3-auto-newline nil))
            (electric-tads3-terminator arg))
        (self-insert-command (prefix-numeric-value arg))))

(defun electric-tads3-semi (arg)
    "Insert character and correct line's indentation."
    (interactive "P")
    (if tads3-auto-newline
        (electric-tads3-terminator arg)
        (self-insert-command (prefix-numeric-value arg))
        (if (tads3-top-level) (tads3-indent-line))))

(defun electric-tads3-enter (arg)
    (interactive "P")
    (if tads3-strip-trailing-whitespace
        (delete-backward-char (- (save-excursion
                                     (skip-chars-backward " \t")))))
    (newline)
    (if tads3-auto-indent-after-newline (tads3-indent-line)))

(defun electric-tads3-terminator (arg)
    "Insert character and correct line's indentation."
    (interactive "P")
    (let (insertpos (end (point)))
        (if (and (not arg) (eolp)
                (not (save-excursion
                         (beginning-of-line)
                         (skip-chars-forward " \t")
                         (or (= (following-char) ?#)
                             ;; Colon is special only after a label, or case ....
                             ;; So quickly rule out most other uses of colon
                             ;; and do no indentation for them.
                             (and (eq last-command-event ?:)
                                 (not (looking-at tads3-switch-label-regexp))
                                 (save-excursion
                                     (skip-chars-forward "a-zA-Z0-9_$")
                                     (skip-chars-forward " \t")
                                     (< (point) end)))
                             (progn
                                 (tads3-beginning-of-defun)
                                 (let ((pps (parse-partial-sexp (point) end)))
                                     (or (nth 3 pps) (nth 4 pps) (nth 5 pps))))))))
            (progn
                (insert last-command-event)
                (tads3-indent-line)
                (and tads3-auto-newline
                    (not (tads3-inside-parens-p))
                    (progn
                        (newline)
                        ;; (newline) may have done auto-fill
                        (setq insertpos (- (point) 2))
                        (tads3-indent-line)))
                (save-excursion
                    (if insertpos (goto-char (1+ insertpos)))
                    (delete-char -1))))
        (if insertpos
            (save-excursion
                (goto-char insertpos)
                (self-insert-command (prefix-numeric-value arg)))
            (self-insert-command (prefix-numeric-value arg)))))

(provide 'tads3)

;;; tads3-mode.el ends here
