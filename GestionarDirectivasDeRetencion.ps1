Connect-ExchangeOnline -UserPrincipalName usuario@dominio.com

$Mailboxes = Get-Mailbox -ResultSize Unlimited -Filter {RecipientTypeDetails -eq "UserMailbox"}

$mailbox = Get-Mailbox -Identity 'usuario@dominio.com'

# Forzar ejecución del proceso 'Managed Folder Asistant'.
$mailbox.Identity | Start-ManagedFolderAssistant

Get-MailboxPlan | Format-Table DisplayName,RetentionPolicy,IsDefault

# Obtener información sobre una directiva de retención.
Get-RetentionPolicy -Identity 'Archivado de correo' | fl

# Ver última vez que se ha ejecutado el proceso 'Managed Folder Assistant'.
[xml]$diag = (Export-MailboxDiagnosticLogs vila -ExtendedProperties).MailboxLog
$diag.Properties.MailboxTable.Property | ? {$_.Name -like "ELC*"}

# Cambiar directiva de retención predeterminada.
Set-MailboxPlan "ExchangeOnlineEnterprise" -RetentionPolicy "Política de retención"