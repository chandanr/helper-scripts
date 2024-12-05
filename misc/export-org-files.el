(load (expand-file-name "~/.emacs"))

(org-show-all)

(add-hook 'org-export-before-parsing-functions 'sjihs-export-translation 0 t)

(org-html-export-to-html)

(remove-hook 'org-export-before-parsing-functions 'sjihs-export-translation t)

(org-ascii-export-to-ascii)


