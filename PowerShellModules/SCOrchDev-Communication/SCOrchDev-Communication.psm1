<#
.SYNOPSIS
    Sends a standard-form automation communication. Assumes two templated mails live in the
    target exchange mailbox to use for success and failure communications
    $TemplateSubjectMap = @{
        'Success' = 'Your automated __REQUEST_NAME__ request has completed successfully';
        'Failure' = 'Your automated __REQUEST_NAME__ request has failed';
    }

.PARAMETER RequestName
    The name of the request that the communication pertains to.

.PARAMETER Type
    Whether the communication indicates success or failure.

.PARAMETER RequestLink
    The link to the request (probably in SharePoint). This link
    will appear in the communication.

.PARAMETER AdditionalInformation
    A string that appears at the foot of the communication. This
    may be used to include error information, for example.
    Consider using Format-AdditionalInformation

.PARAMETER To
    A list of e-mail addresses that the communication will be addressed to.

.PARAMETER Cc
    A list of e-mail addresess that will be carbon-copied on the communication.

.PARAMETER Bcc
    A list of e-mail addresses that will be blind carbon-copied on the communication.

.PARAMETER Contact
    An e-mail address that the communication recipient should contact if they have
    questions.
#>
Function Send-AutomationCommunication
{
    param(
        [Parameter(Mandatory=$True)]
        [String]
        $RequestName,

        [Parameter(Mandatory=$False)]
        [ValidateSet('Success','Failure')]
        [String]
        $Type  = 'Success',

        [Parameter(Mandatory=$False)]
        [AllowNull()]
        [String]
        $RequestLink = $Null,

        [Parameter(Mandatory=$False)]
        [String]
        $AdditionalInformation = $Null,

        [Parameter(Mandatory=$True)]
        [String[]]
        $To,

        [Parameter(Mandatory=$False)]
        [String[]]
        $Cc = $Null,

        [Parameter(Mandatory=$False)]
        [String[]]
        $Bcc = $Null,

        [Parameter(Mandatory=$False)]
        [String]
        $Contact = $Null,

        [Parameter(Mandatory=$False)] 
        [String[]] 
        $Attachments = $Null,

        [Parameter(Mandatory=$True)] 
        [String]
        $TemplateMailboxName,

        [Parameter(Mandatory=$True)] 
        [String]
        $TemplateFolder,

        [Parameter(Mandatory=$True)]
        [pscredential]
        $Credential
    )
    $CompletedParams = Write-StartingMessage

    $RequestLinkStart = ''
    $RequestLinkEnd = ''
    
    if($RequestLink)
    {
        $RequestLinkStart = "<a href='$RequestLink'>"
        $RequestLinkEnd = '</a>'
    }
    $TemplateSubjectMap = @{
        'Success' = 'Your automated __REQUEST_NAME__ request has completed successfully';
        'Failure' = 'Your automated __REQUEST_NAME__ request has failed';
    }
    $TemplateVariables = @{
        '__REQUEST_LINK_START__'     = $RequestLinkStart;
        '__REQUEST_LINK_END__'       = $RequestLinkEnd;
        '__REQUEST_NAME__'           = $RequestName;
        '__CONTACT__'                = Format-FriendlyEmailHyperlink -Name $Contact;
        '__ADDITIONAL_INFORMATION__' = $AdditionalInformation;
    }
    $Subject = Template-String -String $TemplateSubjectMap[$Type] -Template $TemplateVariables
    $SendExchangeTemplateParams = @{
        'TemplateMailboxName' = $TemplateMailboxName ;
        'TemplateFolder' = $TemplateFolder ;
        'TemplateSubject' =  $TemplateSubjectMap[$Type] ;
        'Subject' = $Subject ;
        'To' = $To -as [array] ;
        'Cc' = $Cc -as [array] ;
        'Bcc' = $Bcc -as [array] ;
        'TemplateSubstitutions' = $TemplateVariables ;
        'Credential' = $Credential ;
        'Attachments' = $Attachments
    }
    Send-ExchangeTemplateMailMessage @SendExchangeTemplateParams
    Write-CompletedMessage @CompletedParams
}

<#
.SYNOPSIS
    Sends an e-mail from a template that exists in an Exchange mailbox.

.DESCRIPTION
    Send-ExchangeTemplateMailMessage accesses an Exchange mailbox to obtain a template e-mail and sends it according to
    the parameters passed.  Strings in the template can be replaced by passing a hash or dictionary to
    $TemplateSubstitions.

.PARAMETER TemplateMailboxName
    The name of the Exchange mailbox containing the template, e.g. 'Automation.Communication@genmills.com'.

.PARAMETER Credential
    A PSCredential that has permissions to access the mailbox given by $TemplateMailboxName.

.PARAMETER TemplateFolder
    The name of the folder in the mailbox that contains the template.

.PARAMETER TemplateSubject
    The subject line of the e-mail to use as a template.

.PARAMETER Subject
    The subject line to use when sending the e-mail. Defaults to $TemplateSubject.

.PARAMETER From
    The e-mail address that the sent message should originate from. Defaults to $TemplateMailboxName.
    CURRENTLY NOT IMPLEMENTED.

.PARAMETER To
    A list of e-mail addresses to receive the message.

.PARAMETER Cc
    A list of e-mail addresses to be CC'd on the message.

.PARAMETER Bcc
    A list of e-mail addresses to be BCC'd on the message.

.PARAMETER ImportanceLevel
    The level of importance of the message (one of 'Low', 'Normal', or 'High'). Defaults to 'Normal'.

.PARAMETER RequestReadResponse
    Whether or not to request a read response from the recipients of the message. Defaults to $False.

.PARAMETER RequestDeliveryReceipt
    Whether or not to request a delivery receipt from the recipients of the message. Defaults to $False.

.PARAMETER TemplateSubstitutions
    A hashtable that maps a string to replace with the value that replaces it. E.g. if
    $TemplateSubstitutions = @{'_FIRST_NAME_' = 'John'}, then any instance of '_FIRST_NAME_' in the template will be
    replaced by 'John'.

    A simple search and replace is performed. Regular expressions are not supported.
#>
Function Send-ExchangeTemplateMailMessage
{
    Param(
        [Parameter(Mandatory=$True)]  [String] $TemplateMailboxName,
        [Parameter(Mandatory=$True)]  [PSCredential] $Credential,
        [Parameter(Mandatory=$True)]  [String] $TemplateFolder,
        [Parameter(Mandatory=$True)]  [String] $TemplateSubject,
        [Parameter(Mandatory=$False)] [String] $Subject = $Null,
        [Parameter(Mandatory=$False)] [String] $From = $Null,
        [Parameter(Mandatory=$False)] [String[]] $To = @(),
        [Parameter(Mandatory=$False)] [String[]] $Cc = @(),
        [Parameter(Mandatory=$False)] [String[]] $Bcc = @(),
        [Parameter(Mandatory=$False)] [ValidateSet('Low', 'Normal', 'High')] [String] $ImportanceLevel = 'Normal',
        [Parameter(Mandatory=$False)] [Bool] $RequestReadResponse = $False,
        [Parameter(Mandatory=$False)] [Bool] $RequestDeliveryReceipt = $False,
        [Parameter(Mandatory=$False)] [Hashtable] $TemplateSubstitutions = @{},
        [Parameter(Mandatory=$False)] [String[]] $Attachments = @()
    )
    If((-not $To) -and (-not $Cc) -and (-not $Bcc))
    {
        Throw "One of `$To, `$Cc, or `$Bcc must be specified"
    }
    $ExchangeVersion = 'Exchange2010_SP2'
    $TemplateMailboxConnection = New-EWSMailboxConnection -exchangeVersion $ExchangeVersion `
                                                           -alternateMailboxSMTPAddress $TemplateMailboxName `
                                                           -Credential $Credential

    $Template = Read-EWSEMail -FolderName        $TemplateFolder `
                                -SearchField       'Subject' `
                                -SearchString      $TemplateSubject `
                                -SearchAlgorithm   'Equals' `
                                -readMailFilter    'All' `
                                -maxEmailCount     1 `
                                -mailboxConnection $TemplateMailboxConnection `
                                -doNotMarkRead
    
    $Message = $Template.Copy('Drafts')
    $Message.Body = $Template.Body

    ForEach($Substitution in $TemplateSubstitutions.GetEnumerator())
    {
        $Message.Body.Text = $Message.Body.Text.Replace($Substitution.Name, $Substitution.Value)
    }

    $Message.Subject = Select-FirstValid -Value $Subject, $TemplateSubject
    $From = Select-FirstValid -Value $From, $TemplateMailboxName
    If($From -ne $TemplateMailboxName)
    {
        # TODO: Figure out how to send from a different mailbox than the template resides in
        Throw 'Sending from an address other than $TemplateMailboxName is not implemented'
    }

    $Message.From = $From
    ForEach($Recipient in $To)
    {
        Write-Debug -Message "Adding [$Recipient] as a recipient"
        $Message.ToRecipients.Add($Recipient) | Out-Null
    }  
    ForEach($CCRecipient in $Cc)
    {
        Write-Debug -Message "Adding [$CCRecipient] as a CC recipient"
        $Message.CcRecipients.Add($CCRecipient) | Out-Null
    }
    ForEach($BCCRecipient in $Bcc)
    {
        Write-Debug -Message "Adding [$BCCRecipient] as a BCC recipient"
        $Message.BccRecipients.Add($BCCRecipient) | Out-Null
    }  
    $Message.Importance = [Microsoft.Exchange.WebServices.Data.Importance] $ImportanceLevel
    $Message.IsReadReceiptRequested = $RequestReadResponse
    $Message.IsDeliveryReceiptRequested = $RequestDeliveryReceipt
    ForEach($AttachmentLocation in $Attachments)
    {
        $Message.Attachments.AddFileAttachment($AttachmentLocation) | Out-Null
    } 
    $Message.SendAndSaveCopy()
}

<#
.SYNOPSIS
    Given a hyperlink and optional text, creates an HTML hyperlink.

.PARAMETER Link
    The URL that will be linked to. Mutually exclusive with EmailAddress.

.PARAMETER EmailAddress
    An e-mail address that will be e-mailed if the generated hyperlink
    is clicked on (uses mailto).

.PARAMETER HyperlinkText
    The text that will be displayed in the link. Defaults to the provided
    link / e-mail address.
#>
function Format-Hyperlink
{
    param(
        [Parameter(Mandatory=$True, ParameterSetName='Link')]
        [String]
        $Link,

        [Parameter(Mandatory=$True, ParameterSetName='EmailAddress')]
        [String]
        $EmailAddress,

        [Parameter(Mandatory=$False)]
        [AllowNull()]
        [String]
        $HyperlinkText = $null
    )

    if(Test-IsNullOrEmpty -String $HyperlinkText)
    {
        $HyperlinkText = Select-FirstValid -Value $Link, $EmailAddress
    }
    if($EmailAddress)
    {
        $Link = "mailto:$EmailAddress"
    }
    return "<a href='$Link'>$HyperlinkText</a>"
}

<#
.SYNOPSIS
    Given a display name (e.g. a distlist), returns a corresponding e-mail address.

.PARAMETER Name
    The display name to fetch an e-mail address for.
#>
function Get-MailAddressFromName
{
    param(
        [Parameter(Mandatory=$True)]
        [String]
        $Name
    )

    $ADObject = Get-ADObject -Filter { Name -eq $Name } -Properties 'mail'
    if(-not $ADObject)
    {
        Throw-Exception -Type    'NoSuchDistlist' `
                        -Message "A distribution list with the name '$Name' does not exist" `
                        -Property @{'Name' = $Name}
    }
    return $ADObject.mail
}

<#
.SYNOPSIS
    Given the display name of a distlist or user, returns a hyperlink which e-mails
    that distlist or user.

.PARAMETER Name
    The name of the distribution list or user.
#>
function Format-FriendlyEmailHyperlink
{
    param(
        [Parameter(Mandatory=$True)]
        [String]
        $Name
    )

    $DistlistAddress = Get-MailAddressFromName -Name $Name
    return Format-Hyperlink -EmailAddress $DistlistAddress -HyperlinkText $Name
}

<#
.SYNOPSIS
    A helper method for formatting the "additional information" section of standard
    automated communications. The formatted string will be returned as HTML.

.PARAMETER AdditionalInformation
    The body of the additional information section.

.PARAMETER Header
    An optional header that appears before the additional information.

.PARAMTER Exception
    If specified, the generated additional information section will contain information
    about the provided exception. This parameter is mutually exclusive with AdditionalInformation
    and Header.
#>
function Format-AdditionalInformation
{
    param(
        [Parameter(Mandatory=$True, ParameterSetName='Message')]
        [String]
        $AdditionalInformation,

        [Parameter(Mandatory=$False, ParameterSetName='Message')]
        [AllowNull()]
        [String]
        $Header,

        [Parameter(Mandatory=$False, ParameterSetName='Exception')]
        $Exception = $null
    )

    if($Exception -ne $null)
    {
        $Header = '<b>Error information</b>'
        $AdditionalInformation = Convert-ExceptionToString -Exception $Exception
    }
    $AdditionalInformationString = ''
    if(-not (Test-IsNullOrEmpty -String $Header))
    {
        $AdditionalInformationString += "$Header`n"
    }
    $AdditionalInformationString += $AdditionalInformation
    $AdditionalInformationString = $AdditionalInformationString -replace '\r?\n', "<br />`n"
    return $AdditionalInformationString
}
Export-ModuleMember -Function * -Verbose:$false
