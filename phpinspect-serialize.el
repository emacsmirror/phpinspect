;;; phpinspect-index.el --- PHP parsing and completion package  -*- lexical-binding: t; -*-

;; Copyright (C) 2021  Free Software Foundation, Inc

;; Author: Hugo Thunnissen <devel@hugot.nl>
;; Keywords: php, languages, tools, convenience
;; Version: 0

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'phpinspect-type)
(require 'phpinspect-class)

(cl-defmethod phpinspect--serialize-type ((type phpinspect--type))
  `(phpinspect--make-type
    :name ,(phpinspect--type-name type)
    :collection ,(phpinspect--type-collection type)
    :contains ,(when (phpinspect--type-contains type)
                 (phpinspect--serialize-type (phpinspect--type-contains type)))
    :fully-qualified ,(phpinspect--type-fully-qualified type)))

(cl-defmethod phpinspect--serialize-function ((func phpinspect--function))
  `(phpinspect--make-function
    :name ,(phpinspect--function-name func)
    :scope (quote ,(phpinspect--function-scope func))
    :arguments ,(append '(list)
                        (mapcar (lambda (arg)
                                  `(list ,(car arg) ,(phpinspect--serialize-type (cadr arg))))
                                (phpinspect--function-arguments func)))
    :return-type ,(when (phpinspect--function-return-type func)
                    (phpinspect--serialize-type
                     (phpinspect--function-return-type func)))))

(cl-defmethod phpinspect--serialize-variable ((var phpinspect--variable))
  `(phpinspect--make-variable :name ,(phpinspect--variable-name var)
                              :type ,(when (phpinspect--variable-type var)
                                       (phpinspect--serialize-type
                                        (phpinspect--variable-type var)))
                              :scope (quote ,(phpinspect--variable-scope var))))


(cl-defmethod phpinspect--serialize-indexed-class ((class (head phpinspect--indexed-class)))
  ``(phpinspect--indexed-class
     (class-name . ,,(phpinspect--serialize-type (alist-get 'class-name class)))
     (imports . ,,(append '(list)
                          (mapcar #'phpinspect--serialize-import
                                  (alist-get 'imports class))))
     (methods . ,,(append '(list)
                          (mapcar #'phpinspect--serialize-function
                                  (alist-get 'methods class))))
     (static-methods . ,,(append '(list)
                                 (mapcar #'phpinspect--serialize-function
                                         (alist-get 'static-methods class))))
     (static-variables . ,,(append '(list)
                                   (mapcar #'phpinspect--serialize-variable
                                           (alist-get 'static-variables class))))
     (variables . ,,(append '(list)
                            (mapcar #'phpinspect--serialize-variable
                                    (alist-get 'variables class))))
     (constants . ,,(append '(list)
                            (mapcar #'phpinspect--serialize-variable
                                    (alist-get 'constants class))))
     (extends . ,,(append '(list)
                          (mapcar #'phpinspect--serialize-type
                                  (alist-get 'extends class))))
     (implements . ,,(append '(list)
                             (mapcar #'phpinspect--serialize-type
                                     (alist-get 'implements class))))))

(cl-defmethod phpinspect--serialize-root-index ((index (head phpinspect--root-index)))
  ``(phpinspect--root-index
     (imports . ,,(append '(list)
                          (mapcar #'phpinspect--serialize-import
                                  (alist-get 'imports index))))
     (classes . ,(list
                 ,@(mapcar (lambda (cons-class)
                              `(cons ,(phpinspect--serialize-type (car cons-class))
                                     ,(phpinspect--serialize-indexed-class (cdr cons-class))))
                            (alist-get 'classes index))))
     (functions . ,,(append '(list)
                            (mapcar #'phpinspect--serialize-function
                                    (alist-get 'functions index))))))


(defun phpinspect--serialize-import (import)
  `(cons
    (phpinspect-intern-name ,(symbol-name (car import)))
    ,(phpinspect--serialize-type (cdr import))))

(provide 'phpinspect-serialize)
;;; phpinspect-serialize.el ends here
