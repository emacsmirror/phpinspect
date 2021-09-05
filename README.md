# phpinspect.el

WIP. Documentation is in the making.

Example config:

```elisp
;;;###autoload
(defun my-php-personal-hook ()
  (setq-local company-minimum-prefix-length 0)
  (setq-local company-tooltip-align-annotations t)
  (setq-local company-idle-delay 0.1)
  (setq-local company-backends '(phpinspect-company-backend))

  ;; Shortcut to add use statements for classes you use.
  (define-key php-mode-map (kbd "C-c u") 'phpinspect-fix-uses-interactive)

  ;; Shortcuts to quickly search/open files of PHP classes.
  (global-set-key (kbd "C-c a") 'phpinspect-find-class-file)
  (global-set-key (kbd "C-c c") 'phpinspect-find-own-class-file)

  (phpinspect-mode))

(add-hook 'php-mode-hook #'my-php-personal-hook)
```
