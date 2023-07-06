;; test-buffer.el --- Unit tests for phpinspect.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2021 Free Software Foundation, Inc.

;; Author: Hugo Thunnissen <devel@hugot.nl>

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

;;

;;; Code:

(require 'ert)
(require 'phpinspect-parser)
(require 'phpinspect-buffer)

(ert-deftest phpinspect-parse-buffer-token-locations ()
  "Confirm that the location map of `phpinspect-current-buffer' is
populated when the variable is set and the data in it is accurate."
  (let* ((parsed)
         (class))
    (with-temp-buffer
      (insert-file-contents (concat phpinspect-test-php-file-directory "/NamespacedClass.php"))
      (setq phpinspect-current-buffer
            (phpinspect-make-buffer :buffer (current-buffer)))
      (setq parsed (phpinspect-buffer-parse phpinspect-current-buffer))

      (let* ((class (seq-find #'phpinspect-class-p
                              (seq-find #'phpinspect-namespace-p parsed)))
             (class-meta (phpinspect-buffer-get-token-metadata
                          phpinspect-current-buffer class))
             (class-region (phpinspect-token-metadata-location class-meta))
             (classname-meta (phpinspect-buffer-get-token-metadata
                              phpinspect-current-buffer (car (cddadr class))))
             (classname-region (phpinspect-token-metadata-location classname-meta)))
        (should class)
        (should class-region)
        (should classname-region)
        ;; Character position of the start of the class token.
        (should (= 611 (phpinspect-region-start class-region)))
        (should (= 2367 (phpinspect-region-end class-region)))

        (should (= 617 (phpinspect-region-start classname-region)))
        (should (= 634 (phpinspect-region-end classname-region)))))))

(ert-deftest phpinspect-parse-buffer-no-current ()
  "Confirm that the parser is still functional with
`phpinspect-current-buffer' unset."
  (let*((buffer)
        (parsed))
    (with-temp-buffer
      (should-not phpinspect-current-buffer)
      (insert-file-contents (concat phpinspect-test-php-file-directory "/NamespacedClass.php"))
      (setq parsed (phpinspect-parse-current-buffer)))

    (should (cdr parsed))))
