;;; parse-file.el --- Benchmarks of phpinspect parser in different configurations  -*- lexical-binding: t; -*-

;; Copyright (C) 2023  Free Software Foundation, Inc

;; Author: Hugo Thunnissen <devel@hugot.nl>
;; Keywords: benchmark

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


(require 'phpinspect-parser)

(defun phpinspect-parse-current-buffer ()
  (phpinspect-parse-buffer-until-point
   (current-buffer)
   (point-max)))

(let ((here (file-name-directory (or load-file-name buffer-file-name))))

  (with-temp-buffer
    (insert-file-contents (concat here "/Response.php"))

    (message "Incremental parse (warmup):")
    (phpinspect-with-parse-context (phpinspect-make-pctx :incremental t :bmap (phpinspect-make-bmap))
      (benchmark 1 '(phpinspect-parse-current-buffer)))

    (let ((bmap (phpinspect-make-bmap))
          (bmap2 (phpinspect-make-bmap)))
      (message "Incremental parse:")
      (phpinspect-with-parse-context (phpinspect-make-pctx :incremental t :bmap bmap)
        (benchmark 1 '(phpinspect-parse-current-buffer)))

      (garbage-collect)

      (message "Incremental parse (no edits):")
      (phpinspect-with-parse-context (phpinspect-make-pctx :incremental t
                                                           :bmap bmap2
                                                           :previous-bmap bmap
                                                           :edtrack (phpinspect-make-edtrack))
        (benchmark 1 '(phpinspect-parse-current-buffer)))

      (garbage-collect)

      (message "Incremental parse repeat (no edits):")
      (phpinspect-with-parse-context (phpinspect-make-pctx :incremental t
                                                           :bmap (phpinspect-make-bmap)
                                                           :previous-bmap bmap2
                                                           :edtrack (phpinspect-make-edtrack))
        (benchmark 1 '(phpinspect-parse-current-buffer)))

      (garbage-collect)

      (let ((edtrack (phpinspect-make-edtrack))
            (bmap (phpinspect-make-bmap))
            (bmap-after (phpinspect-make-bmap)))
        ;; Fresh
        (phpinspect-with-parse-context (phpinspect-make-pctx :incremental t :bmap bmap)
          (phpinspect-parse-current-buffer))

        (message "Incremental parse after buffer edit:")
        ;; Removes closing curly brace of __construct
        (goto-char 9062)
        (delete-backward-char 1)

        (garbage-collect)

        (phpinspect-edtrack-register-edit edtrack 9061 9061 1)
        (phpinspect-with-parse-context (phpinspect-make-pctx :bmap bmap-after :incremental t :previous-bmap bmap :edtrack edtrack)
          (benchmark 1 '(phpinspect-parse-current-buffer)))

        (phpinspect-edtrack-clear edtrack)
        (insert "{")

        (phpinspect-edtrack-register-edit edtrack 9061 9062 0)
        ;; Mark region as edit without length deta
        (phpinspect-edtrack-register-edit edtrack 19552 19562 10)

        (garbage-collect)

        ;;(profiler-start 'cpu)
        (message "Incremental parse after 2 more edits:")
        (phpinspect-with-parse-context (phpinspect-make-pctx :bmap (phpinspect-make-bmap)
                                                             :incremental t
                                                             :previous-bmap bmap-after
                                                             :edtrack edtrack)
          (benchmark 1 '(phpinspect-parse-current-buffer)))

        ;; (save-current-buffer
        ;;   (profiler-stop)
        ;;   (profiler-report)
        ;;   (profiler-report-write-profile (concat here "/profile.txt")))
        )))

  (with-temp-buffer
    (insert-file-contents (concat here "/Response.php"))

    (garbage-collect)
    (message "Bare (no token reuse) parse (warmup):")
    (benchmark 1 '(phpinspect-parse-current-buffer))


    (garbage-collect)
    (message "Bare (no token reuse) parse:")
    (benchmark 1 '(phpinspect-parse-current-buffer))))
