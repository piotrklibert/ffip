;;                           _    _     ___ ____ _____
;;                          / \  | |   |_ _/ ___|_   _|
;;                         / _ \ | |    | |\___ \ | |
;;                        / ___ \| |___ | | ___) || |
;;                       /_/   \_\_____|___|____/ |_|
;;                                   UTILS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Found, by accident, in elscreen source. Extracted from there. Somehow I was
;; sure that there will be better support for alists (like in Erlang for
;; example) in Elisp, but it turns out it's not there by default.

(defun util-get-alist (key alist)
  (cdr (assoc key alist)))


(defun util-remove-alist (symbol key)
  "Delete an element whose car equals KEY from the alist bound to
SYMBOL."
  (when (boundp symbol)
    (set symbol (util-del-alist key (symbol-value symbol)))))


(defun util-del-alist (key alist)
  "Delete an element whose car equals KEY from ALIST.
Return the modified ALIST."
  (let ((pair (assoc key alist)))
    (if pair (delq pair alist) alist)))


(defun util-set-alist (symbol key value)
  "Set cdr of an element (KEY . ...) in the alist bound to SYMBOL
to VALUE."
  (or (boundp symbol)
      (set symbol nil))
  (set symbol (util-put-alist key value (symbol-value symbol))))


(defun util-put-alist (key value alist)
  "Set cdr of an element (KEY . ...) in ALIST to VALUE and return ALIST.
If there is no such element, create a new pair (KEY . VALUE) and
return a new alist whose car is the new pair and cdr is ALIST."
  (let ((elm (assoc key alist)))
    (if (not elm)
        (cons (cons key value) alist)
      (setcdr elm value)
      alist)))
