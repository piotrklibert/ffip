**fuzzy-find-in-project.el - Emacs binding to the `fuzzy_file_finder` rubygem.**

License:

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

Commentary
----------

Requires ruby, rubygems, and the `fuzzy_file_finder` rubygem.

The `fuzzy_file_finder` rubygem can be installed with the following command:

    sudo gem install --source http://gems.github.com jamis-fuzzy_file_finder

Usage
-----

The primary interface into the functionality provided by this file is through
the `fuzzy-find-in-project` function. Calling this function will match the query to
the files under `fuzzy-find-project-root` and open up a completion buffer with
the first matched file selected (with a `> `.) The selection can be changed using
`C-n` and `C-p`, and the currently selected file can be opened using `<RET>`.

Installation
--------------

In your .emacs or init.el:

    (add-to-list 'load-path "~/.emacs.d/path/to/fuzzy-find-in-project")
    (require 'fuzzy-find-in-project)

Example config
-------------

(taken from my .emacs)

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

    ;; There's a bit of a mess in my "misc projects" folder, and some of its
    ;; directories have much too many files in them, so I need to prune them before
    ;; adding them to `fuzzy-find-roots'.
    (require 'f)
    (lexical-let*
        ((ignored (--map (f-expand (f-join "~/poligon/" it))
                         '("books-dedup" "django-debug-toolbar"
                           "django-rest-framework" "haxe"
                           "old_web_app_template" "poligon")))
         (subdirs (f-directories (f-expand "~/poligon/")
                                 (lambda (path)
                                   (not (-contains? ignored path)))))
         (new-ffip-dirs (append (util-get-alist 'prv fuzzy-find-roots)
                                subdirs)))
      (util-put-alist 'prv new-ffip-dirs fuzzy-find-roots)
      ;; make FFIP notice the change in in dirs
      (fuzzy-find-choose-root-set "prv"))
