# Fuzzy Find in Project (ffip) - `fuzzy_file_finder` for Emacs. #


## Commentary ##

This is a ground-up rewrite of original `fuzzy-find-in-project` plugin for
Emacs. I did this hoping to learn Elisp better in the process and hoping to
improve user experience of `ffip`. This plugin is very much in a "works for me"
state, and it lacks many customization options, is not fully documented and so
on.

`ffip` basic purpose is to let you open a specific file quickly, even if you
don't remember what exactly is its name or path. It also works for quickly
listing contents of deeply nested directories with its interface (see
Screenshot). It's somewhat similar to `CtrlP`, a Vim plugin.

`FFIP` only does file name/file path matching, nothing more. If you want a
universal fuzzy completer try IDo and/or Helm. If you want to *quickly* find
files with specific contents, I recommend https://github.com/Wilfred/ag.el,
which is much faster than alternatives (ack, grin, find+grep and so on) and/or
use `ctags` or something similar.

## Usage ##

The primary interface into the functionality provided by this file is through
the `fuzzy-find-in-project` function. Calling this function will match the query to
the files under current set of root directories and open up a completion buffer with
the first matched file selected (with a `> `.) The selection can be changed using
`<UP>` and `<DOWN>`, and the currently selected file can be opened using `<RET>`.

You define your root directories with `ffip-defroots` macro, and you can change
currently searched directory set with `fuzzy-find-choose-root-set` - this
prompts for a new directory set name with autocompletion.


## Installation ##

Requires ruby, rubygems, and the `fuzzy_file_finder` rubygem.

The `fuzzy_file_finder` rubygem can be installed with the following command:

    sudo gem install --source http://gems.github.com jamis-fuzzy_file_finder

Requires `s` and `dash` Elisp libraries, which can be obtained from MELPA.

In your .emacs or init.el:

    (add-to-list 'load-path "~/.emacs.d/path/to/fuzzy-find-in-project")
    (require 'fuzzy-find-in-project)

## Example config ##

(taken from my .emacs)

```elisp
;; fuzzy-find configuration, defines named directory groups for easy changing
;; between them and current/default group for use before the root is changed
;; explicitly
(ffip-defroots 'prv ("~/todo/")
  (tag . ("/usr/www/tagasauris/tagasauris/"
          "/usr/www/tagasauris/src/tenclouds/tenclouds/"
          "/usr/www/tagasauris/control/"
          "/usr/www/tagasauris/config/"
          "/usr/www/tagasauris/doc/"))
  (ion . ("~/ion/code/"))
  (sp  . ("~/smartpatient/smartpatient-web/smartpatient/"))
  (prv . ("~/mgmnt/" "~/priv/"
          "~/.emacs.d/pkg-langs/elpy/"
          "~/.emacs.d/config/"
          "~/.emacs.d/plugins2/"
          "~/.emacs.d/pkg-langs/")))

;; There's a bit of a mess in my "misc projects" folder (called "poligon"), and
;; some of its directories have much too many files in them, so I need to prune
;; them before adding them to `fuzzy-find-roots'.
(require 'f)
(lexical-let*
    ((ignored (--map (f-expand (f-join "~/poligon/" it))
                     '("books-dedup" "django-debug-toolbar"
                       "django-rest-framework" "h axe"
                       "old_web_app_template" "poligon")))
     (valid-subdirs (f-directories (f-expand "~/poligon/")
                             (lambda (path)
                               (not (-contains? ignored path)))))
     (new-ffip-dirs (append (util-get-alist 'prv fuzzy-find-roots)
                            valid-subdirs)))
  (util-put-alist 'prv new-ffip-dirs fuzzy-find-roots)

  ;; make FFIP notice the change in dirs
  (fuzzy-find-choose-root-set "prv"))
```

Screenshot
----------

![screenshot](https://raw.githubusercontent.com/piotrklibert/ffip/master/img/ffip-screenshot.png)


## License: ##

Copyright (c) 2008 Justin Weiss

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

http://www.avvo.com
