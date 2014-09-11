# --
# Kernel/Modules/AgentTicketCustomer.pm - to set the ticket customer and show the customer history
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketCustomer;

use strict;
use warnings;

use Kernel::System::CustomerUser;
# ---
# Znuny4OTRS-CustomerViewDynamicFields
# ---
use Kernel::System::DynamicField;
use Kernel::System::DynamicField::Backend;
# ---
use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # check needed Objects
    for my $Needed (qw(ParamObject DBObject TicketObject LayoutObject LogObject ConfigObject)) {
        if ( !$Self->{$Needed} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $Needed!" );
        }
    }

    $Self->{Search}     = $Self->{ParamObject}->GetParam( Param => 'Search' )     || 0;
    $Self->{CustomerID} = $Self->{ParamObject}->GetParam( Param => 'CustomerID' ) || '';

    # customer user object
    $Self->{CustomerUserObject} = Kernel::System::CustomerUser->new(%Param);
# ---
# Znuny4OTRS-CustomerViewDynamicFields
# ---
    $Self->{DynamicFieldObject}        = Kernel::System::DynamicField->new( %{ $Self } );
    $Self->{DynamicFieldBackendObject} = Kernel::System::DynamicField::Backend->new( %{ $Self } );
# ---

    $Self->{Config} = $Self->{ConfigObject}->Get("Ticket::Frontend::$Self->{Action}");

# ---
# Znuny4OTRS-CustomerViewDynamicFields
# ---
    # get the dynamic fields for this screen
    $Self->{DynamicField} = $Self->{DynamicFieldObject}->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => ['Ticket'],
        FieldFilter => $Self->{Config}->{DynamicField} || {},
    );
# ---

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Output;

    # check needed stuff
    if ( !$Self->{TicketID} ) {

        # error page
        return $Self->{LayoutObject}->ErrorScreen(
            Message => 'No TicketID is given!',
            Comment => 'Please contact the admin.',
        );
    }

    # check permissions
    if (
        !$Self->{TicketObject}->TicketPermission(
            Type     => $Self->{Config}->{Permission},
            TicketID => $Self->{TicketID},
            UserID   => $Self->{UserID}
        )
        )
    {

        # error screen, don't show ticket
        return $Self->{LayoutObject}->NoPermission(
            Message    => "You need $Self->{Config}->{Permission} permissions!",
            WithHeader => 'yes',
        );
    }

    # check permissions
    if ( $Self->{TicketID} ) {
        if (
            !$Self->{TicketObject}->TicketPermission(
                Type     => 'customer',
                TicketID => $Self->{TicketID},
                UserID   => $Self->{UserID}
            )
            )
        {

            # no permission screen, don't show ticket
            return $Self->{LayoutObject}->NoPermission( WithHeader => 'yes' );
        }
    }

    # get ACL restrictions
    $Self->{TicketObject}->TicketAcl(
        Data          => '-',
        TicketID      => $Self->{TicketID},
        ReturnType    => 'Action',
        ReturnSubType => '-',
        UserID        => $Self->{UserID},
    );
    my %AclAction = $Self->{TicketObject}->TicketAclActionData();

    # check if ACL restrictions exist
    if ( IsHashRefWithData( \%AclAction ) ) {

        # show error screen if ACL prohibits this action
        if ( defined $AclAction{ $Self->{Action} } && $AclAction{ $Self->{Action} } eq '0' ) {
            return $Self->{LayoutObject}->NoPermission( WithHeader => 'yes' );
        }
    }

    if ( $Self->{Subaction} eq 'Update' ) {

        # challenge token check for write action
        $Self->{LayoutObject}->ChallengeTokenCheck();

        # set customer id
        my $ExpandCustomerName1 = $Self->{ParamObject}->GetParam( Param => 'ExpandCustomerName1' )
            || 0;
        my $ExpandCustomerName2 = $Self->{ParamObject}->GetParam( Param => 'ExpandCustomerName2' )
            || 0;
        my $CustomerUserOption = $Self->{ParamObject}->GetParam( Param => 'CustomerUserOption' )
            || '';
        $Param{CustomerUserID} = $Self->{ParamObject}->GetParam( Param => 'CustomerUserID' ) || '';
        $Param{CustomerID}     = $Self->{ParamObject}->GetParam( Param => 'CustomerID' )     || '';
        $Param{SelectedCustomerUser}
            = $Self->{ParamObject}->GetParam( Param => 'SelectedCustomerUser' ) || '';

        # use customer login instead of email address if applicable
        if ( $Param{SelectedCustomerUser} ne '' ) {
            $Param{CustomerUserID} = $Param{SelectedCustomerUser};
        }

        # Expand Customer Name
        if ($ExpandCustomerName1) {

            # search customer
            my %CustomerUserList = ();
            %CustomerUserList
                = $Self->{CustomerUserObject}->CustomerSearch( Search => $Param{CustomerUserID}, );

            # check if just one customer user exists
            # if just one, fillup CustomerUserID and CustomerID
            $Param{CustomerUserListCount} = 0;
            for my $KeyCustomerUser ( sort keys %CustomerUserList ) {
                $Param{CustomerUserListCount}++;
                $Param{CustomerUserListLast}     = $CustomerUserList{$KeyCustomerUser};
                $Param{CustomerUserListLastUser} = $KeyCustomerUser;
            }
            if ( $Param{CustomerUserListCount} == 1 ) {
                $Param{CustomerUserID} = $Param{CustomerUserListLastUser};
                my %CustomerUserData = $Self->{CustomerUserObject}->CustomerUserDataGet(
                    User => $Param{CustomerUserListLastUser},
                );
                if ( $CustomerUserData{UserCustomerID} ) {
                    $Param{CustomerID} = $CustomerUserData{UserCustomerID};
                }

            }

            # if more the one customer user exists, show list
            # and clean CustomerID
            else {
                $Param{CustomerID} = '';
                $Param{"CustomerUserOptions"} = \%CustomerUserList;
            }
# ---
# Znuny4OTRS-CustomerViewDynamicFields
# ---
# Not needed to be changed, since the 'ExpandCustomerName1' function is not used
# ---
            return $Self->Form(%Param);
        }

        # get customer user and customer id
        elsif ($ExpandCustomerName2) {
            my %CustomerUserData
                = $Self->{CustomerUserObject}->CustomerUserDataGet( User => $CustomerUserOption, );
            my %CustomerUserList
                = $Self->{CustomerUserObject}->CustomerSearch( UserLogin => $CustomerUserOption, );
            for my $KeyCustomerUser ( sort keys %CustomerUserList ) {
                $Param{CustomerUserID} = $KeyCustomerUser;
            }
            if ( $CustomerUserData{UserCustomerID} ) {
                $Param{CustomerID} = $CustomerUserData{UserCustomerID};
            }
# ---
# Znuny4OTRS-CustomerViewDynamicFields
# ---
# Not needed to be changed, since the 'ExpandCustomerName2' function is not used
# ---
            return $Self->Form(%Param);
        }

        my %Error;

        # check needed data
        if ( !$Param{CustomerUserID} ) {
            $Error{'CustomerUserIDInvalid'} = 'ServerError';
        }
        if ( !$Param{CustomerID} ) {
            $Error{'CustomerIDInvalid'} = 'ServerError';
        }

# ---
# Znuny4OTRS-CustomerViewDynamicFields
# ---
#         if (%Error) {
#             return $Self->Form( { %Param, %Error } );
#         }
        # get dynamic field values form http request
        my %DynamicFieldValues;

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            # extract the dynamic field value form the web request
            $DynamicFieldValues{ $DynamicFieldConfig->{Name} }
                = $Self->{DynamicFieldBackendObject}->EditFieldValueGet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ParamObject        => $Self->{ParamObject},
                LayoutObject       => $Self->{LayoutObject},
                );
        }

        # convert dynamic field values into a structure for ACLs
        my %DynamicFieldACLParameters;
        DYNAMICFIELD:
        for my $DynamicField ( sort keys %DynamicFieldValues ) {
            next DYNAMICFIELD if !$DynamicField;
            next DYNAMICFIELD if !$DynamicFieldValues{$DynamicField};

            $DynamicFieldACLParameters{ 'DynamicField_' . $DynamicField }
                = $DynamicFieldValues{$DynamicField};
        }
        $Param{DynamicField} = \%DynamicFieldACLParameters;

        # create html strings for all dynamic fields
        my %DynamicFieldHTML;

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $PossibleValuesFilter;

            my $IsACLReducible = $Self->{DynamicFieldBackendObject}->HasBehavior(
                DynamicFieldConfig => $DynamicFieldConfig,
                Behavior           => 'IsACLReducible',
            );

            if ($IsACLReducible) {

                # get PossibleValues
                my $PossibleValues = $Self->{DynamicFieldBackendObject}->PossibleValuesGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                );

                # check if field has PossibleValues property in its configuration
                if ( IsHashRefWithData($PossibleValues) ) {

                    # convert possible values key => value to key => key for ACLs using a Hash slice
                    my %AclData = %{$PossibleValues};
                    @AclData{ keys %AclData } = keys %AclData;

                    # set possible values filter from ACLs
                    my $ACL = $Self->{TicketObject}->TicketAcl(
                        %Param,
                        Action        => $Self->{Action},
                        TicketID      => $Self->{TicketID},
                        ReturnType    => 'Ticket',
                        ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                        Data          => \%AclData,
                        UserID        => $Self->{UserID},
                    );
                    if ($ACL) {
                        my %Filter = $Self->{TicketObject}->TicketAclData();

                        # convert Filer key => key back to key => value using map
                        %{$PossibleValuesFilter}
                            = map { $_ => $PossibleValues->{$_} }
                            keys %Filter;
                    }
                }
            }

            my $ValidationResult = $Self->{DynamicFieldBackendObject}->EditFieldValueValidate(
                DynamicFieldConfig   => $DynamicFieldConfig,
                PossibleValuesFilter => $PossibleValuesFilter,
                ParamObject          => $Self->{ParamObject},
                Mandatory =>
                    $Self->{Config}->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
            );

            if ( !IsHashRefWithData($ValidationResult) ) {
                return $Self->{LayoutObject}->ErrorScreen(
                    Message =>
                        "Could not perform validation on field $DynamicFieldConfig->{Label}!",
                    Comment => 'Please contact the admin.',
                );
            }

            # propagate validation error to the Error variable to be detected by the frontend
            if ( $ValidationResult->{ServerError} ) {
                $Error{ $DynamicFieldConfig->{Name} } = ' ServerError';
            }

            # get field html
            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } =
                $Self->{DynamicFieldBackendObject}->EditFieldRender(
                    DynamicFieldConfig   => $DynamicFieldConfig,
                    PossibleValuesFilter => $PossibleValuesFilter,
                    Mandatory =>
                        $Self->{Config}->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                    ServerError  => $ValidationResult->{ServerError}  || '',
                    ErrorMessage => $ValidationResult->{ErrorMessage} || '',
                    LayoutObject => $Self->{LayoutObject},
                    ParamObject  => $Self->{ParamObject},
                );
        }

        if (%Error) {
            return $Self->Form(
                %Param,
                %Error,
                DynamicFieldHTML => \%DynamicFieldHTML,
            );
        }

        # set dynamic fields
        # cycle through the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            # set the value
            my $Success = $Self->{DynamicFieldBackendObject}->ValueSet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $Self->{TicketID},
                Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
                UserID             => $Self->{UserID},
            );
        }
# ---

        # update customer user data
        if (
            $Self->{TicketObject}->TicketCustomerSet(
                TicketID => $Self->{TicketID},
                No       => $Param{CustomerID},
                User     => $Param{CustomerUserID},
                UserID   => $Self->{UserID},
            )
            )
        {

            # redirect
            return $Self->{LayoutObject}->PopupClose(
                URL => "Action=AgentTicketZoom;TicketID=$Self->{TicketID}",
            );
        }
        else {

            # error?!
            return $Self->{LayoutObject}->ErrorScreen();
        }
    }

    # show form
    else {
# ---
# Znuny4OTRS-CustomerViewDynamicFields
# ---
#         return $Self->Form(%Param);
        my %Ticket = $Self->{TicketObject}->TicketGet(
            TicketID      => $Self->{TicketID},
            UserID        => $Self->{UserID},
            DynamicFields => 1,
        );

        # create html strings for all dynamic fields
        my %DynamicFieldHTML;

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $PossibleValuesFilter;

            my $IsACLReducible = $Self->{DynamicFieldBackendObject}->HasBehavior(
                DynamicFieldConfig => $DynamicFieldConfig,
                Behavior           => 'IsACLReducible',
            );

            if ($IsACLReducible) {

                # get PossibleValues
                my $PossibleValues = $Self->{DynamicFieldBackendObject}->PossibleValuesGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                );

                # check if field has PossibleValues property in its configuration
                if ( IsHashRefWithData($PossibleValues) ) {

                    # convert possible values key => value to key => key for ACLs using a Hash slice
                    my %AclData = %{$PossibleValues};
                    @AclData{ keys %AclData } = keys %AclData;

                    # set possible values filter from ACLs
                    my $ACL = $Self->{TicketObject}->TicketAcl(
                        %Param,
                        Action        => $Self->{Action},
                        TicketID      => $Self->{TicketID},
                        ReturnType    => 'Ticket',
                        ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                        Data          => \%AclData,
                        UserID        => $Self->{UserID},
                    );
                    if ($ACL) {
                        my %Filter = $Self->{TicketObject}->TicketAclData();

                        # convert Filer key => key back to key => value using map
                        %{$PossibleValuesFilter}
                            = map { $_ => $PossibleValues->{$_} }
                            keys %Filter;
                    }
                }
            }

            # get field html
            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } =
                $Self->{DynamicFieldBackendObject}->EditFieldRender(
                    DynamicFieldConfig   => $DynamicFieldConfig,
                    PossibleValuesFilter => $PossibleValuesFilter,
                    Value                => $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
                    Mandatory =>
                        $Self->{Config}->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                    LayoutObject    => $Self->{LayoutObject},
                    ParamObject     => $Self->{ParamObject},
                );
        }

        return $Self->Form(
            %Param,
            DynamicFieldHTML => \%DynamicFieldHTML,
        );
# ---
    }
}

sub Form {
    my ( $Self, %Param ) = @_;

    my $Output;

    # print header
    $Output .= $Self->{LayoutObject}->Header(
        Type => 'Small',
    );
    my $TicketCustomerID = $Self->{CustomerID};

    # print change form if ticket id is given
    my %CustomerUserData = ();
    if ( $Self->{TicketID} ) {

        # set some customer search autocomplete properties
        $Self->{LayoutObject}->Block(
            Name => 'CustomerSearchAutoComplete',
        );

        # get ticket data
        my %TicketData = $Self->{TicketObject}->TicketGet( TicketID => $Self->{TicketID} );

        if ( $TicketData{CustomerUserID} || $Param{CustomerUserID} ) {
            %CustomerUserData = $Self->{CustomerUserObject}->CustomerUserDataGet(
                User => $Param{CustomerUserID} || $TicketData{CustomerUserID},
            );
        }
        $TicketCustomerID = $TicketData{CustomerID};
        $Param{SelectedCustomerUser} = $TicketData{CustomerUserID};

        $Param{Table} = $Self->{LayoutObject}->AgentCustomerViewTable(
            Data => \%CustomerUserData,
            Max  => $Self->{ConfigObject}->Get('Ticket::Frontend::CustomerInfoComposeMaxSize'),
        );

        # show customer field as "FirstName Lastname" <MailAddress>
        if (%CustomerUserData) {
            $TicketData{CustomerUserID} = "\"$CustomerUserData{UserFirstname} " .
                "$CustomerUserData{UserLastname}\" <$CustomerUserData{UserEmail}>";
        }
        $Self->{LayoutObject}->Block(
            Name => 'Customer',
            Data => { %TicketData, %Param, },
        );
    }

# ---
# Znuny4OTRS-CustomerViewDynamicFields
# ---
    # Dynamic fields
    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {

        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # skip fields that HTML could not be retrieved
        next DYNAMICFIELD if !IsHashRefWithData(
            $Param{DynamicFieldHTML}->{ $DynamicFieldConfig->{Name} }
        );

        # get the html strings form $Param
        my $DynamicFieldHTML = $Param{DynamicFieldHTML}->{ $DynamicFieldConfig->{Name} };

        $Self->{LayoutObject}->Block(
            Name => 'DynamicField',
            Data => {
                Name  => $DynamicFieldConfig->{Name},
                Label => $DynamicFieldHTML->{Label},
                Field => $DynamicFieldHTML->{Field},
            },
        );

        # example of dynamic fields order customization
        $Self->{LayoutObject}->Block(
            Name => 'DynamicField_' . $DynamicFieldConfig->{Name},
            Data => {
                Name  => $DynamicFieldConfig->{Name},
                Label => $DynamicFieldHTML->{Label},
                Field => $DynamicFieldHTML->{Field},
            },
        );
    }
# ---

    $Output
        .= $Self->{LayoutObject}->Output( TemplateFile => 'AgentTicketCustomer', Data => \%Param );
    $Output .= $Self->{LayoutObject}->Footer(
        Type => 'Small',
    );
    return $Output;
}

1;
