(require 's)
(require 'dash)
(require 'thingatpt)


(eval-when-compile
  (require 'cl))

(load "./alist-util.el")

(defmacro ffip-defroots (current commons &rest alist)
  (declare (indent defun))
  (let (roots names)
    (dolist (r alist)
      (let*
          ((paths (append (cdr r) commons))
           (expanded (-map 'f-expand  paths)))
        (push `(,(car r)  ,@expanded) roots)
        (push (symbol-name (car r)) names)))
    `(progn
       (setq fuzzy-find-roots (quote ,roots))
       (setq fuzzy-find-root-names (quote ,names))
       (setq fuzzy-find-project-root (cdr (assoc ,current ',roots))))))


(defvar fuzzy-find-roots nil "")
(defvar fuzzy-find-root-names nil "")

(defvar fuzzy-find-project-root nil "")


(defvar fuzzy-find-mode-active               nil          "Tells the minibuffer when to use the fuzzy finder")
(defvar fuzzy-find-selection-moved           nil          "True if the previous command moved the selection on the completions list")
(defvar fuzzy-find-process                   nil          "Holds the process that runs the fuzzy_find_file rubygem")
(defvar fuzzy-find-completions               ""           "Contains the current file name completions")
(defvar fuzzy-find-completion-buffer-name    "*FFiP*"     "The name of the buffer to display the possible file name completions")
(defvar fuzzy-find-selected-completion-index 1            "1-based index of the currently selected completion")
(defvar fuzzy-find-in-project-setup-hook     nil          "Hook that runs after fuzzy-find-in-project initialization")
(defvar fuzzy-find-setup                     nil          "True if setup was run already")
(defvar fuzzy-find-debug                     nil          "Turns on verbose logging if t")

(defconst fuzzy-find-setup-hooks
  '((minibuffer-setup-hook . ffip--minibuf-setup-hook)
    (minibuffer-exit-hook  . ffip--minibuf-exit-hook))
  "Hooks to attach when first initializing the plugin")

(defvar fuzzy-find-keymap  (make-sparse-keymap))
(define-key fuzzy-find-keymap "\C-n"         'ffip--next-completion)
(define-key fuzzy-find-keymap (kbd "<down>") 'ffip--next-completion)
(define-key fuzzy-find-keymap "\C-p"         'ffip--previous-completion)
(define-key fuzzy-find-keymap (kbd "<up>")   'ffip--previous-completion)
(define-key fuzzy-find-keymap "\r"           'ffip--selected-file)

(defalias 'buf-substr-np 'buffer-substring-no-properties)


(defface ffip-selected-face
  '((t :foreground "orange" :box "red" :height 110))
  "Font face used for highlighting current selection in files list.")


;;
;;                              PUBLIC INTERFACE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun fuzzy-find-in-project ()
  "A mode for quickly finding a file you need. It displays a list
of possible completions after every letter typed when active.
Completions are 'fuzzy', which means that you don't need to type
the file path exaclty as it is. For example, to find a
'statics/js/accounts/some.js' you can input any of:

s/s.js
st/acc/som
js/ats/

The last one only if 'some.js' is lexicographicaly first in the
'accounts' directory listing, though.

The mode supports multiple root directories, changing root
directories on the fly and creates one long lived process in the
background so that accessing your files is easy and convenient.

Configurable exclusion patterns comming up next!
"
  (interactive)
  (unless fuzzy-find-setup
    (ffip--start-or-restart-process)
    (ffip--map-hooks 'add-hook)
    (setq fuzzy-find-setup 'done))
  (ffip--start)
  (setq fuzzy-find-selected-file nil)
  (read-string "Find file: ")
  (with-current-buffer fuzzy-find-completion-buffer-name
    (let ((buffer-read-only nil))
      (fuzzy-find-unmark-line fuzzy-find-selected-completion-index)))
  (when fuzzy-find-selected-file
    (find-file fuzzy-find-selected-file)))

(defun fuzzy-find-change-root (roots)
  "Edit and set a new value for `fuzzy-find-project-root' and restart the
backend process."
  (interactive
   (list (edit-and-eval-command "Change ffip root dirs: "
                                `(list ,@fuzzy-find-project-root))))
  (setq fuzzy-find-project-root roots)
  (ffip--start-or-restart-process))

(defun fuzzy-find-choose-root-set (root-set-name)
  "TODO: I'm your docstring, pls write me!"
  (interactive
   ;; t for REQUIRE-MATCH means that we will get fully expanded/completed name
   ;; even if user hits return without completing the name (ie. pr<return>
   ;; instead of pr<tab><enter>)
   (list (completing-read "Choose the set of root dirs: "
                          fuzzy-find-root-names nil t "" 'fuzzy-find-root-names)))
  (let*
      ((root-set-symbol (intern root-set-name))
       (dirs (cdr (assoc root-set-symbol fuzzy-find-roots))))
    (setq fuzzy-find-project-root dirs)
    (ffip--start-or-restart-process)))



(defun fuzzy-find-query-backend (query)
  "Send a query to the backend and block until either a response arrives or
timeout is exceeded."
  (fuzzy-find-completions-clear)
  (ffip--send-process query)
  (unless (wait-for-response-milliseconds 2000)
    (error "Time out while waiting for completions."))
  (setq fuzzy-find-completions (s-chop-suffix "\nEND\n" fuzzy-find-completions))
  (ffip--log "completions:" (s-chop-suffix fuzzy-find-completions "\nEND\n"))
  fuzzy-find-completions)


;; TODO: these setters are probably unneeded
(defun ffip--start () (setq fuzzy-find-mode-active t))
(defun ffip--stop () (setq fuzzy-find-mode-active nil))

;;
;;                             HOOKS AND HANDLERS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun ffip--minibuf-setup-hook ()
  "Executed everytime something activates minibuffer. If it
happens when ffip mode is active attaches `post-command-hook' and
adds keys to minibuffer-local-map keymap."
  (when fuzzy-find-mode-active
    (ffip--log "Adding keys")
    (add-hook 'post-command-hook 'ffip--command-hook nil t)
    (set-keymap-parent fuzzy-find-keymap minibuffer-local-map)
    (use-local-map fuzzy-find-keymap)))

(defun ffip--minibuf-exit-hook ()
  "Complement to `ffip--minibuf-setup-hook', besides removing
keys and hook it terminates ffip mode."
  (when fuzzy-find-mode-active
    (ffip--log "Removing keys")
    (remove-hook 'post-command-hook 'ffip--command-hook t)
    (use-local-map (keymap-parent fuzzy-find-keymap)))
  (setq fuzzy-find-mode-active nil))

(defun ffip--command-hook ()
  "Invoked in the context of minibuffer, everytime a key is
pressed. Causes a completions buffer to display a fresh
completions if a string in minibuffer changed."
  (if (and fuzzy-find-mode-active
           (not fuzzy-find-selection-moved))
      (progn
        (ffip--log "Resetting index" last-command)
        (setq fuzzy-find-selected-completion-index 1)
        (fuzzy-find-display-completions (fuzzy-find-read-minibuffer)))
    (setq fuzzy-find-selection-moved nil)))

(defun ffip--next-completion ()
  "Move selection to the next completion."
  (interactive)
  (setq fuzzy-find-selection-moved t)
  (fuzzy-find-mark-completion 1))

(defun ffip--previous-completion ()
  "Move selection to the previous completion."
  (interactive)
  (setq fuzzy-find-selection-moved t)
  (fuzzy-find-mark-completion -1))

(defun ffip--selected-file ()
  "Find a file matching active completion and display it's buffer."
  (interactive)
  (with-current-buffer fuzzy-find-completion-buffer-name
    (setq fuzzy-find-selected-file
          (fuzzy-find-read-line fuzzy-find-selected-completion-index)))
  (exit-minibuffer))


(defun ffip--map-hooks (func)
  "Map a func over a list of setup hooks defined by this module."
  (loop for hook in fuzzy-find-setup-hooks
        do (funcall func (car hook) (cdr hook))))


;;
;;                         BACKEND PROCESS HANDLING
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun ffip--start-process ()
  "Start asynchronous process and register it's filter function."
  (let* ;; make arguments for ruby module
      ((ruby-mod-path (locate-file "fuzzy-find-in-project.rb" load-path))
       (finder-roots (ffip--format-roots fuzzy-find-project-root))
       (args (append (list "ruby" ruby-mod-path) finder-roots)))

    (setq fuzzy-find-completions "")
    (setq fuzzy-find-process (apply 'start-process "ffip" nil args))
    (set-process-query-on-exit-flag fuzzy-find-process nil)

    (set-process-filter fuzzy-find-process 'fuzzy-find-completions-concat)
    fuzzy-find-process))

(defun ffip--stop-process ()
  (interrupt-process fuzzy-find-process)
  (setq fuzzy-find-process nil))


(defun ffip--find-process ()
  (--filter (string-match-p "ffip" (process-name it)) (process-list)))

(defun ffip--start-or-restart-process ()
  "Clean all processes that look like they're created by this
module and then start one again. Usefull for debugging when a
process somehow wasn't killed and during development for
restarting process to use new code. "
  (let ((active-ffips (ffip--find-process)))
   (if (and (not fuzzy-find-process) (not active-ffips))
       (ffip--start-process)
     (loop initially (setq fuzzy-find-process nil)
           for proc in active-ffips
           do (interrupt-process proc)
           finally (progn
                     (sit-for 15)
                     (ffip--start-process))))))

(defun fuzzy-find-restart ()
  "Restart backend process. Should be called after changing root
dirs list."
  (interactive)
  (ffip--start-or-restart-process))

(defun ffip--send-process (str)
  (process-send-string fuzzy-find-process (concat str "\n")))

(defun fuzzy-find-completions-concat (process output)
  (setq fuzzy-find-completions (concat fuzzy-find-completions output)))

(defun fuzzy-find-completions-clear ()
  (setq fuzzy-find-completions ""))



;;
;;                       COMPLETIONS DISPLAY FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defun fuzzy-find-display-completions (query)
  (ffip--log "displaying completions for:" query)
  (let ((buf (get-buffer-create fuzzy-find-completion-buffer-name)))
    (with-current-buffer buf
      (let ((buffer-read-only nil))
        (erase-buffer)
        (insert (fuzzy-find-query-backend query))
        (fuzzy-find-mark-line fuzzy-find-selected-completion-index))
      (goto-char (point-min))
      (forward-line (1- fuzzy-find-selected-completion-index))
      (display-buffer buf))))

(defun fuzzy-find-mark-line (line-number)
  "Highlights line at `line-number' and inserts '> ' at the
beginning of line."
  (save-excursion
    (goto-char (point-min))             ; goto-line maybe?
    (forward-line (1- fuzzy-find-selected-completion-index))
    (insert "> ")
    (add-text-properties (line-beginning-position)
                         (line-end-position)
                         '(face ffip-selected-face))))



(defun fuzzy-find-unmark-line (line-number)
  "Removes '> ' from the beginning of line `line-number' if it
begins with '> '."
  (save-excursion
    (goto-char (point-min))
    (forward-line (1- fuzzy-find-selected-completion-index))
    (let ((line (buf-substr-np (line-beginning-position)
                               (line-end-position))))
      (when (s-starts-with? "> " line)
        (delete-char 2)
        (remove-text-properties (line-beginning-position)
                                (line-end-position)
                                '(face nil))))))
;; TODO: make dealing with "> " at the beginning of selected completion saner.
(defun fuzzy-find-read-line (line-number)
  (save-excursion
    (goto-line line-number)
    (let ((line (buf-substr-np (line-beginning-position)
                               (line-end-position))))
      (s-chop-prefix "> " line))))

(defun fuzzy-find-mark-completion (completion-index-delta)
  "Moves the completion index marker by `completion-index-delta'
and marks the line corresponding to the currently selected
completion."
  (with-current-buffer  fuzzy-find-completion-buffer-name
    (let
        ((buffer-read-only nil)
         (lines-count      (count-lines (point-min) (point-max)))
         (new-index        (+ completion-index-delta
                              fuzzy-find-selected-completion-index)))

      (fuzzy-find-unmark-line fuzzy-find-selected-completion-index)
      (setq fuzzy-find-selected-completion-index new-index)

      ;; reset completion index if it falls out of bounds
      (if (< fuzzy-find-selected-completion-index 1)
          (setq fuzzy-find-selected-completion-index 1))
      (if (> fuzzy-find-selected-completion-index lines-count)
          (setq fuzzy-find-selected-completion-index lines-count))

      (fuzzy-find-mark-line fuzzy-find-selected-completion-index))
    ;; move point to selected line and center window on it
    (goto-char (point-min))
    (forward-line (1- fuzzy-find-selected-completion-index))
    (set-window-point (get-buffer-window) (point))))


;;
;;                                  HELPERS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defun ffip--log (&rest things)
  (when fuzzy-find-debug
    (with-current-buffer (get-buffer "*Messages*")
      (loop for thing in things
            do (insert (format "%s\n" thing))))))

(defun wait-for-response-milliseconds (milliseconds &optional resolution)
  (loop for count from 0 to (/ milliseconds 10)
        if (s-ends-with? "\nEND\n" fuzzy-find-completions) return t
        do (sleep-for 0 (or resolution 10))
        finally return nil))

(defun ffip--format-roots (roots)
  "Return roots if it's a list, otherwise return '(roots)"
  (cond ((listp roots)    roots)
        ((stringp roots) (list roots))))

(defun fuzzy-find-read-minibuffer ()
  (buf-substr-np (minibuffer-prompt-end) (point-max)))



(provide 'fuzzy-find-in-project)
