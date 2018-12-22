;;; documentation.lisp --- Accessing DOCUMENTATION

(/debug "loading documentation.lisp!")

;;; Documentation.
(defun documentation (x type)
  "Return the documentation of X. TYPE must be the symbol VARIABLE or FUNCTION."
  (ecase type
    (function
     (let ((func (fdefinition x)))
       (oget func "docstring")))
    (variable
     (unless (symbolp x)
       (error "The type of documentation `~S' is not a symbol." type))
     (oget x "vardoc"))))


;;; APROPOS and friends

(defun map-apropos-symbols (function string package external-only)
  (flet ((handle-symbol (symbol)
           (when (search string (symbol-name symbol) :test #'char-equal)
             (funcall function symbol))))
    (if package
        (if external-only
            (do-external-symbols (symbol package) (handle-symbol symbol))
            (do-symbols (symbol package) (handle-symbol symbol)))
        (if external-only
            (do-all-external-symbols (symbol) (handle-symbol symbol))
            (do-all-symbols (symbol) (handle-symbol symbol))))))

(defun apropos/regexp-test (pattern str)
  ((oget pattern "test")  str))

(defun apropos-list (string &optional package externals-only)
  (let* ((result '())
         (pattern (#j:RegExp string))
         (comparator (lambda (x)
                       (let ((name (symbol-name x)))
                         (when (apropos/regexp-test pattern name)
                           (pushnew  x result :test 'eq)))))
         (single-package (lambda (pkg)
                           (map-for-in comparator (if externals-only
                                                      (%package-external-symbols pkg)
                                                      (%package-symbols pkg))))))
    (if package
        (funcall single-package package)
        (map-for-in single-package *package-table*))
    result))

(defun apropos (string &optional package externals-only)
  (princ
   (with-output-to-string (buf)
     (dolist (it (apropos-list string  package externals-only))
       (prin1 it buf)
       (when (boundp it)
         (princ ",  Value: " buf)
         (prin1 (symbol-value it) buf))
       (when (fboundp it)
         (princ ",  Def: " buf)
         (if (find-generic-function it nil)
             (princ "Standard generic function" buf)
             (princ "Function" buf)))
       (format buf "~%"))))
  (terpri)
  (values))

;;; DESCRIBE

;; TODO: this needs DESCRIBE-OBJECT as generic method
;; TODO: indentation for nested paragraphs
(defun describe (object &optional stream)
  (declare (ignore stream))
  (typecase object
    (cons
     (format t "~S~%  [cons]~%" object))
    (integer
     (format t "~S~%  [integer]~%" object))
    (symbol
     (format t "~S~%  [symbol]~%" object)
     (when (boundp object)
       (format t "~%~A names a special variable:~%  Value: ~A~%"
               object (symbol-value object))
       (let ((documentation (documentation object 'variable)))
         (when documentation
           (format t "  Documentation:~%~A~%" documentation))))
     (when (fboundp object)
       (format t "~%~A names a function:~%" object)
       (let ((documentation (documentation object 'function)))
         (when documentation
           (format t "  Documentation:~%~A~%" documentation)))))
    (string
     (format t "~S~%  [string]~%~%Length: ~D~%"
             object (length object)))
    (float
     (format t "~S~%  [float]~%" object))
    (array
     (format t "~S~%  [array]~%" object))
    (function
     (format t "~S~%  [function]~%" object)
     (let ((documentation (documentation object 'function)))
       (when documentation
         (format t "  Documentation:~%~A~%" documentation))))
    (T
     (warn "~A not implemented yet for ~A" 'describe object)))
  (values))
