# PSAppMgmtTK
PowerShell App Management Toolkit

This is meant to be a set of tools used by Dev-Ops administrators, to publish applications to MECM while creating appropriate AD groups.

ComputerAppMgmt is also included in this repository. It is designed to bypass the wait of helpdesk adding a computer to an AD group and the wait for MECM to pickup on that change, the collection to update, the client to pickup the updated collection.
Instead, the script attempts copying the source files to the computer and performing a remote install. It also adds the computer to the AD group, for tracking, and app managemtn.

