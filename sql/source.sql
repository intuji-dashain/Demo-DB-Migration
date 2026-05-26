create table dbo.dtproperties
(
    id       int identity,
    objectid int,
    property varchar(64)                                    not null,
    value    varchar(255),
    uvalue   nvarchar(255),
    lvalue   image,
    version  int
        constraint DF__dtpropert__versi__77BFCB91 default 0 not null,
    constraint pk_dtproperties
        primary key (id, property)
            with (fillfactor = 85)
)
go

create table dbo.sysdiagrams
(
    name         sysname not null,
    principal_id int     not null,
    diagram_id   int identity
        primary key,
    version      int,
    definition   varbinary(max),
    constraint UK_principal_name
        unique (principal_id, name)
)
go

exec sp_addextendedproperty 'microsoft_database_tools_support', 1, 'SCHEMA', 'dbo', 'TABLE', 'sysdiagrams'
go

create table dbo.tblActionType
(
    ActionTypeID   int identity
        constraint PK_tblServiceType
            primary key
                with (fillfactor = 85),
    ActionTypeName varchar(100),
    AmountMinimum  decimal(10, 2)
)
go

create table dbo.tblAmalgamatedClients
(
    AmalgamatedID              int identity
        constraint PK_tblAmalgamatedClients
            primary key
                with (fillfactor = 85),
    ClientID                   int not null,
    BusinessID                 int,
    ClientStatusID             int,
    FirstName                  varchar(50),
    SurName                    varchar(50),
    Address                    varchar(100),
    Suburb                     varchar(50),
    Postcode                   varchar(4),
    PhoneNumber                varchar(20),
    EmailAddress               varchar(50),
    Gender                     varchar,
    DOB                        datetime,
    IndigenousTypeID           int,
    UMRN                       varchar(50),
    CardTypeID                 int,
    CardNumber                 varchar(50),
    OtherEligibilityCriteriaID int,
    BusinessClientNumber       varchar(50),
    Comment                    varchar(300),
    DateCreated                datetime,
    CreatedBy                  int,
    DateModified               datetime,
    ModifiedBy                 int,
    ProviderID                 varchar(20),
    AmalgamatedClientID        int,
    AmalgamationDate           datetime
)
go

create table dbo.tblApplicationArea
(
    ApplicationAreaID      int not null
        constraint PK_tblApplicationArea
            primary key
                with (fillfactor = 85),
    ApplicationAreaName    varchar(50),
    ApplicationAreaLevel   int,
    ApplicationAreaWebForm varchar(50),
    SessionParameter       int
)
go

create table dbo.tblBudgetDistributionRatio
(
    BudgetDistributionRatioID int identity
        constraint PK_tblBudgetDistributionRatio
            primary key
                with (fillfactor = 85),
    Quarter1                  decimal,
    Quarter2                  decimal,
    Quarter3                  decimal,
    Quarter4                  decimal
)
go

create table dbo.tblBusinessHistory
(
    BusinessID              int not null,
    BusinessName            varchar(100),
    BusinessStatusID        int,
    ParentID                int,
    Address                 varchar(100),
    Suburb                  varchar(50),
    Postcode                varchar(10),
    SLA                     bit,
    Specialist              bit,
    HealthProvider          bit,
    Comment                 varchar(300),
    Logo                    binary(50),
    DateCreated             datetime,
    CreatedBy               int,
    DateModified            datetime,
    ModifiedBy              int,
    FinancialYear           int,
    Container               bit,
    InternalServiceProvider bit,
    HealthOrDoc             bit
)
go

create table dbo.tblBusinessStatus
(
    BusinessStatusID   int identity
        constraint PK_tblBusinessStatus
            primary key
                with (fillfactor = 85),
    BusinessStatusName varchar(50)
)
go

create table dbo.tblBusiness
(
    BusinessID              int identity
        constraint PK_tblBusiness
            primary key
                with (fillfactor = 85),
    BusinessName            varchar(100),
    BusinessStatusID        int
        constraint FK_tblBusiness_tblBusinessStatus
            references dbo.tblBusinessStatus,
    ParentID                int
        constraint FK_tblBusiness_tblBusiness
            references dbo.tblBusiness,
    Address                 varchar(100),
    Suburb                  varchar(50),
    Postcode                varchar(10),
    SLA                     bit,
    Specialist              bit,
    HealthProvider          bit,
    Comment                 varchar(300),
    Logo                    binary(50),
    DateCreated             datetime,
    CreatedBy               int,
    DateModified            datetime,
    ModifiedBy              int,
    Container               bit
        constraint DF__tblBusine__Conta__36BCDA92 default 0         not null,
    InternalServiceProvider bit
        constraint DF_tblBusiness_InternalServiceProvider default 0 not null,
    HealthOrDoc             bit
        constraint DF_tblBusiness_HealthOrDoc default 0             not null
)
go

create table dbo.tblBudget
(
    BudgetID        int identity
        constraint PK_tblBudget
            primary key
                with (fillfactor = 85),
    BusinessID      int
        constraint FK_tblBudget_tblBusiness
            references dbo.tblBusiness
            on update cascade,
    BudgetStartDate datetime,
    Quarter1        decimal(10, 2),
    Quarter2        decimal(10, 2),
    Quarter3        decimal(10, 2),
    Quarter4        decimal(10, 2),
    DateCreated     datetime,
    CreatedBy       int,
    DateModified    datetime,
    ModifiedBy      int
)
go

create index IX_BusinessID
    on dbo.tblBudget (BusinessID)
    with (fillfactor = 85)
go

create index IX_BusinessStatusID
    on dbo.tblBusiness (BusinessStatusID)
    with (fillfactor = 85)
go

create index IX_ParentID
    on dbo.tblBusiness (ParentID)
    with (fillfactor = 85)
go

create table dbo.tblBusinessAccount
(
    BusinessAccountID             int identity
        constraint PK_tblCostCentre
            primary key
                with (fillfactor = 85),
    BusinessAccountName           varchar(60),
    OpeningBalanceDate            datetime,
    OpeningBalanceAvailableAmount decimal,
    OpeningBalanceCurrentAmount   decimal,
    AmountAvailable               decimal(10, 2),
    AmountCurrent                 decimal(10, 2),
    BusinessID                    int
        constraint FK_tblCostCentre_tblBusiness
            references dbo.tblBusiness
            on update cascade
)
go

create index IX_BusinessID
    on dbo.tblBusinessAccount (BusinessID)
    with (fillfactor = 85)
go

create table dbo.tblBusinessApplicationArea
(
    BusinessApplicationAreaID int identity
        constraint PK_tblBusinessApplicationArea
            primary key
                with (fillfactor = 85),
    ApplicationAreaID         int
        constraint FK_tblBusinessApplicationArea_tblApplicationArea
            references dbo.tblApplicationArea
            on update cascade,
    BusinessID                int
        constraint FK_tblBusinessApplicationArea_tblBusiness
            references dbo.tblBusiness
            on update cascade
)
go

create index IX_ApplicationAreaID
    on dbo.tblBusinessApplicationArea (ApplicationAreaID)
    with (fillfactor = 85)
go

create index IX_BusinessID
    on dbo.tblBusinessApplicationArea (BusinessID)
    with (fillfactor = 85)
go

create table dbo.tblBusinessCostCentre
(
    BusinessCostCentreID   int identity
        constraint PK_tblBusinessCostCentre
            primary key
                with (fillfactor = 85),
    BusinessCostCentreCode varchar(50),
    BusinessCostCentreName varchar(50),
    BusinessID             int
        constraint FK_tblBusinessCostCentre_tblBusiness
            references dbo.tblBusiness
            on update cascade
)
go

create index IX_BusinessID
    on dbo.tblBusinessCostCentre (BusinessID)
    with (fillfactor = 85)
go

create table dbo.tblCardType
(
    CardTypeID   int identity
        constraint PK_tblCardType
            primary key
                with (fillfactor = 85),
    CardTypeName varchar(50)
)
go

create table dbo.tblCeilingPriceLevel
(
    CeilingPriceLevelID   int identity
        constraint PK_tblAuthorisationLevel
            primary key
                with (fillfactor = 85),
    CeilingPriceLevelName varchar(50)
)
go

create table dbo.tblClientStatus
(
    ClientStatusiD   int identity
        constraint PK_tblClientStatus
            primary key
                with (fillfactor = 85),
    ClientStatusName varchar(20)
)
go

create table dbo.tblDestinationType
(
    DestinationTypeID   int not null
        constraint PK_tblDestinationType
            primary key
                with (fillfactor = 85),
    DestinationTypeName varchar(50)
)
go

create table dbo.tblEligibilityDetermined
(
    EligibilityDeterminedID   int identity
        constraint PK_tblEligibiliyDetermined
            primary key
                with (fillfactor = 85),
    EligibilityDeterminedName varchar(100)
)
go

create table dbo.tblEnvironmentSetting
(
    SendEmail bit
)
go

create table dbo.tblEquipmentActionExclusionOverride
(
    EquipmentActionExclusionOverride int identity
        constraint PK_tblEquipmentActionExclusionOverride
            primary key
                with (fillfactor = 85),
    EquipmentActionID                int                                   not null,
    Active                           bit
        constraint DF_tblEquipmentActionExclusionOverride_Active default 0 not null,
    DateCreated                      datetime,
    CreatedBy                        int,
    DateModified                     datetime,
    ModifiedBy                       int
)
go

create table dbo.tblEquipmentActionLimit
(
    RowId  int identity
        constraint PK_tblEquipmentActionLimit
            primary key,
    Limit  decimal(18, 2) not null,
    [From] decimal(18, 2) not null,
    [To]   decimal(18, 2) not null
)
go

create table dbo.tblEquipmentActionPriority
(
    EquipmentActionPriorityID   int identity,
    EquipmentActionPriorityName nvarchar(50) not null
)
go

create table dbo.tblEquipmentActionStatus
(
    EquipmentActionStatusID   int not null
        constraint PK_tblEquipmentStatus
            primary key
                with (fillfactor = 85),
    EquipmentActionStatusName varchar(50),
    EquipmentActionStatusRank int
)
go

create table dbo.tblEquipmentCategory
(
    EquipmentCategoryID   int identity
        constraint PK_tblEquipmentCategory
            primary key
                with (fillfactor = 85),
    EquipmentCategoryName varchar(300)
)
go

create table dbo.tblEquipmentStatus
(
    EquipmentStatusID   int not null
        constraint PK_tblEquipmentStatus_1
            primary key
                with (fillfactor = 85),
    EquipmentStatusName varchar(50),
    EquipmentStatusRank int
)
go

create table dbo.tblEquipmentType
(
    EquipmentTypeID     int identity
        constraint PK_tblEquipmentType
            primary key
                with (fillfactor = 85),
    EquipmentTypeName   varchar(300),
    EquipmentCategoryID int
        constraint FK_tblEquipmentType_tblEquipmentCategory
            references dbo.tblEquipmentCategory,
    EquipmentTypeCode   int,
    [Current]           bit,
    MaximumQuantity     int,
    ApplyLoading        bit
)
go

create index IX_EquipmentCategoryID
    on dbo.tblEquipmentType (EquipmentCategoryID)
    with (fillfactor = 85)
go

create table dbo.tblEquipmentTypeCeilingPriceLevel
(
    EquipmentTypeCeilingPriceLevelid int identity
        constraint PK_tblEquipmentTypeAuthorisationLevel
            primary key
                with (fillfactor = 85),
    CeilingPriceLevelID              int
        constraint FK_tblEquipmentTypeCeilingPriceLevel_tblCeilingPriceLevel
            references dbo.tblCeilingPriceLevel,
    EquipmentTypeID                  int
        constraint FK_tblEquipmentTypeCeilingPriceLevel_tblEquipmentType
            references dbo.tblEquipmentType,
    CeilingPrice                     decimal(10, 2)
)
go

create index IX_CeilingPriceLevelID
    on dbo.tblEquipmentTypeCeilingPriceLevel (CeilingPriceLevelID)
    with (fillfactor = 85)
go

create index IX_EquipmentTypeID
    on dbo.tblEquipmentTypeCeilingPriceLevel (EquipmentTypeID)
    with (fillfactor = 85)
go

create table dbo.tblEquipmentTypeProperty
(
    EquipmentTypePropertyID int identity
        constraint PK_tblEquipmentUserField
            primary key
                with (fillfactor = 85),
    EquipmentTypeID         int
        constraint FK_tblEquipmentTypeProperty_tblEquipmentType
            references dbo.tblEquipmentType
            on delete cascade,
    BusinessID              int
        constraint FK_tblEquipmentTypeProperty_tblBusiness
            references dbo.tblBusiness
            on update cascade,
    PropertyName            varchar(100),
    DateCreated             datetime,
    CreatedBy               int,
    DateModified            datetime,
    ModifiedBy              int
)
go

create index IX_BusinessID
    on dbo.tblEquipmentTypeProperty (BusinessID)
    with (fillfactor = 85)
go

create index IX_EquipmentTypeID
    on dbo.tblEquipmentTypeProperty (EquipmentTypeID)
    with (fillfactor = 85)
go

create table dbo.tblExclusionGroup
(
    ExclusionGroupID   int identity
        constraint PK_tblExclusionGroup
            primary key
                with (fillfactor = 85),
    ExclusionGroupName varchar(100),
    ExclusionGroupCode varchar(4)
)
go

create table dbo.tblExclusionEquipmentType
(
    ExclusionEquipmentTypeID int identity
        constraint PK_tblExclusion
            primary key
                with (fillfactor = 85),
    ExclusionGroupID         int
        constraint FK_tblExclusionEquipmentType_tblExclusionGroup
            references dbo.tblExclusionGroup
            on delete cascade,
    EquipmentTypeID          int
        constraint FK_tblExclusionEquipmentType_tblEquipmentType
            references dbo.tblEquipmentType
            on delete cascade
)
go

create index IX_EquipmentTypeID
    on dbo.tblExclusionEquipmentType (EquipmentTypeID)
    with (fillfactor = 85)
go

create index IX_ExclusionGroupID
    on dbo.tblExclusionEquipmentType (ExclusionGroupID)
    with (fillfactor = 85)
go

create table dbo.tblExtract
(
    Record varchar(8000)
)
go

create table dbo.tblIndigenousType
(
    IndigenousTypeID   int not null
        constraint PK_tblIndigenousType
            primary key
                with (fillfactor = 85),
    IndigenousTypeName varchar(100)
)
go

create table dbo.tblInformation
(
    ID               int identity,
    Category         int            not null,
    BriefDescription nvarchar(70)   not null,
    LongDescription  nvarchar(1000) not null,
    NewsDate         datetime       not null,
    ShowOnNews       smallint       not null,
    Archived         smallint       not null,
    DateCreated      datetime       not null
)
go

create table dbo.tblInformationAttachment
(
    ID            int identity,
    InformationID int           not null,
    Name          nvarchar(100) not null,
    Type          nvarchar(100) not null,
    Length        int           not null,
    Data          image         not null
)
go

create table dbo.tblInformationCategory
(
    ID   int identity,
    Name nvarchar(50) not null
)
go

create table dbo.tblInvoiceStatus
(
    InvoiceStatusID   int not null
        constraint PK_tblInvoiceStatus
            primary key
                with (fillfactor = 85),
    InvoiceStatusName varchar(50),
    InvoiceStatusRank int
)
go

create table dbo.tblInvoice
(
    InvoiceID       int identity
        constraint PK_tblEquipmentinvoice
            primary key
                with (fillfactor = 85),
    InvoiceStatusID int
        constraint FK_tblInvoice_tblInvoiceStatus
            references dbo.tblInvoiceStatus
            on update cascade,
    Description     varchar(300),
    Number          varchar(20),
    Amount          decimal(10, 2),
    DateInvoice     datetime,
    DatePaid        datetime,
    BusinessID      int
        constraint FK_tblEquipmentInvoice_tblBusiness
            references dbo.tblBusiness
            on update cascade,
    SupplierName    varchar(100),
    DateCreated     datetime,
    CreatedBy       int,
    DateModified    datetime,
    ModifiedBy      int
)
go

create index IX_BusinessID
    on dbo.tblInvoice (BusinessID)
    with (fillfactor = 85)
go

create index IX_InvoiceStatusID
    on dbo.tblInvoice (InvoiceStatusID)
    with (fillfactor = 85)
go

create table dbo.tblInvoiceStatusAudit
(
    InvoiceStatusAuditID int identity
        constraint PK_tblnvoiceStatusAudit
            primary key
                with (fillfactor = 85),
    InvoiceID            int
        constraint FK_tblInvoiceStatusAudit_tblInvoice
            references dbo.tblInvoice,
    InvoiceStatusIDFrom  int
        constraint FK_tblInvoiceStatusAudit_tblInvoiceStatus
            references dbo.tblInvoiceStatus,
    InvoiceStatusIDTo    int
        constraint FK_tblInvoiceStatusAudit_tblInvoiceStatus1
            references dbo.tblInvoiceStatus,
    Amount               decimal,
    BusinessID           int,
    DateCreated          datetime,
    CreatedBy            int
)
go

create index IX_InvoiceID
    on dbo.tblInvoiceStatusAudit (InvoiceID)
    with (fillfactor = 85)
go

create index IX_InvoiceStatusIDFrom
    on dbo.tblInvoiceStatusAudit (InvoiceStatusIDFrom)
    with (fillfactor = 85)
go

create index IX_InvoiceStatusIDTo
    on dbo.tblInvoiceStatusAudit (InvoiceStatusIDTo)
    with (fillfactor = 85)
go

create table dbo.tblLogonStatus
(
    LogonStatusID   int not null
        constraint PK_tblLoginStatus
            primary key
                with (fillfactor = 85),
    LogonStatusName varchar(50)
)
go

create table dbo.tblMessage
(
    MessageID          int not null
        constraint PK_tblMessage
            primary key
                with (fillfactor = 85),
    MessageDescription varchar(1000),
    MessageType        int,
    HasParameters      bit,
    ShowNumber         bit
)
go

create table dbo.tblMode
(
    ModeID   int not null
        constraint PK_tblModes
            primary key
                with (fillfactor = 85),
    ModeName varchar(50)
)
go

create table dbo.tblApplicationAreaMode
(
    ApplicationAreaModeID int not null
        constraint PK_tblApplicationAreaMode
            primary key
                with (fillfactor = 85),
    ApplicationAreaID     int
        constraint FK_tblApplicationAreaMode_tblApplicationArea
            references dbo.tblApplicationArea
            on update cascade,
    ModeID                int
        constraint FK_tblApplicationAreaMode_tblMode
            references dbo.tblMode
            on update cascade,
    Priority              int
)
go

create index IX_ApplicationAreaID
    on dbo.tblApplicationAreaMode (ApplicationAreaID)
    with (fillfactor = 85)
go

create index IX_ModeID
    on dbo.tblApplicationAreaMode (ModeID)
    with (fillfactor = 85)
go

create table dbo.tblMenu
(
    MenuID                int not null
        constraint PK_tblMenuNEW
            primary key
                with (fillfactor = 85),
    ParentID              int,
    MenuDescription       varchar(200),
    Caption               varchar(50),
    ApplicationAreaModeID int
        constraint FK_tblMenu_tblApplicationAreaMode
            references dbo.tblApplicationAreaMode,
    Root                  bit,
    RootRank              int,
    Form                  bit,
    FormRank              int,
    InLine                bit,
    AccessKey             varchar,
    Command               bit
)
go

create table dbo.tblApplicationAreaMenu
(
    ApplicationAreaMenuID int identity
        constraint PK_tblApplicationAreaPermissionRole
            primary key
                with (fillfactor = 85),
    ApplicationAreaID     int
        constraint FK_tblApplicationAreaMenu_tblApplicationArea
            references dbo.tblApplicationArea
            on update cascade,
    MenuID                int
        constraint FK_tblApplicationAreaMenu_tblMenu
            references dbo.tblMenu
            on update cascade
)
go

create index IX_ApplicationAreaID
    on dbo.tblApplicationAreaMenu (ApplicationAreaID)
    with (fillfactor = 85)
go

create index IX_MenuID
    on dbo.tblApplicationAreaMenu (MenuID)
    with (fillfactor = 85)
go

create index IX_ApplicationAreaModeID
    on dbo.tblMenu (ApplicationAreaModeID)
    with (fillfactor = 85)
go

create table dbo.tblOtherEligibilityCriteria
(
    OtherEligibilityCriteriaID   int identity
        constraint PK_tblOtherEligibilityCriteria
            primary key
                with (fillfactor = 85),
    OtherEligibilityCriteriaName varchar(50)
)
go

create table dbo.tblClient
(
    ClientID                   int identity
        constraint PK_tblClient
            primary key
                with (fillfactor = 85),
    BusinessID                 int
        constraint FK_tblClient_tblBusiness
            references dbo.tblBusiness
            on update cascade,
    ClientStatusID             int
        constraint FK_tblClient_tblClientStatus
            references dbo.tblClientStatus,
    FirstName                  varchar(50) masked with (function = 'partial(1, "XXXX", 0)'),
    SurName                    varchar(50) masked with (function = 'partial(1, "XXXX", 0)'),
    Address                    varchar(100) masked with (function = 'default()'),
    Suburb                     varchar(50),
    Postcode                   varchar(4),
    PhoneNumber                varchar(20) masked with (function = 'default()'),
    EmailAddress               varchar(50) masked with (function = 'email()'),
    Gender                     varchar,
    DOB                        datetime masked with (function = 'default()'),
    IndigenousTypeID           int
        constraint FK_tblClient_tblIndigenousType
            references dbo.tblIndigenousType
            on update cascade,
    UMRN                       varchar(50) masked with (function = 'default()'),
    CardTypeID                 int
        constraint FK_tblClient_tblCardType
            references dbo.tblCardType,
    CardNumber                 varchar(50) masked with (function = 'partial(0, "XXXX-XXXX-XXXX-", 4)'),
    OtherEligibilityCriteriaID int
        constraint FK_tblClient_tblOtherEligibilityCriteria
            references dbo.tblOtherEligibilityCriteria,
    BusinessClientNumber       varchar(50),
    Comment                    varchar(300),
    DateCreated                datetime,
    CreatedBy                  int,
    DateModified               datetime,
    ModifiedBy                 int,
    ProviderID                 varchar(20)
)
go

create index IX_BusinessID
    on dbo.tblClient (BusinessID)
    with (fillfactor = 85)
go

create index IX_CardTypeID
    on dbo.tblClient (CardTypeID)
    with (fillfactor = 85)
go

create index IX_ClientStatusID
    on dbo.tblClient (ClientStatusID)
    with (fillfactor = 85)
go

create index IX_IndigenousTypeID
    on dbo.tblClient (IndigenousTypeID)
    with (fillfactor = 85)
go

create index IX_OtherEligibilityCriteriaID
    on dbo.tblClient (OtherEligibilityCriteriaID)
    with (fillfactor = 85)
go

create index Ix_Suburb
    on dbo.tblClient (Suburb)
    with (fillfactor = 85)
go

create index missing_index_157
    on dbo.tblClient (CardTypeID, CardNumber, ClientID)
    with (fillfactor = 85)
go

create index missing_index_160
    on dbo.tblClient (FirstName, SurName, DOB, ClientID)
    with (fillfactor = 85)
go

create index missing_index_223
    on dbo.tblClient (UMRN, ClientID)
    with (fillfactor = 85)
go

create index missing_index_29432
    on dbo.tblClient (SurName, FirstName)
    with (fillfactor = 85)
go

create index missing_index_31622
    on dbo.tblClient (UMRN, ClientID)
    with (fillfactor = 85)
go

grant select on dbo.tblClient to MaskingTestUser
go

create table dbo.tblClientBusinessAudit
(
    ClientBusinessAuditID int identity
        constraint PK_tblClientHistory
            primary key
                with (fillfactor = 85),
    ClientID              int
        constraint FK_tblClientBusinessAudit_tblClient
            references dbo.tblClient,
    BusinessIDFrom        int
        constraint FK_tblClientBusinessAudit_tblBusiness
            references dbo.tblBusiness,
    BusinessIDTo          int
        constraint FK_tblClientBusinessAudit_tblBusiness1
            references dbo.tblBusiness,
    DateCreated           datetime,
    CreatedBy             int
)
go

create index IX_BusinessIDFrom
    on dbo.tblClientBusinessAudit (BusinessIDFrom)
    with (fillfactor = 85)
go

create index IX_BusinessIDTo
    on dbo.tblClientBusinessAudit (BusinessIDTo)
    with (fillfactor = 85)
go

create index IX_ClientID
    on dbo.tblClientBusinessAudit (ClientID)
    with (fillfactor = 85)
go

create table dbo.tblClientStatusAudit
(
    ClientStatusAuditID int identity
        constraint PK_tblClientStatusHistory
            primary key
                with (fillfactor = 85),
    ClientID            int
        constraint FK_tblClientStatusAudit_tblClient
            references dbo.tblClient,
    ClientStatusIDFrom  int
        constraint FK_tblClientStatusAudit_tblClientStatus
            references dbo.tblClientStatus,
    ClientStatusIDTo    int
        constraint FK_tblClientStatusAudit_tblClientStatus1
            references dbo.tblClientStatus,
    DateCreated         datetime,
    CreatedBy           int
)
go

create index IX_ClientID
    on dbo.tblClientStatusAudit (ClientID)
    with (fillfactor = 85)
go

create index IX_ClientStatusIDFrom
    on dbo.tblClientStatusAudit (ClientStatusIDFrom)
    with (fillfactor = 85)
go

create index IX_ClientStatusIDTo
    on dbo.tblClientStatusAudit (ClientStatusIDTo)
    with (fillfactor = 85)
go

create table dbo.tblReferralLevel
(
    ReferralLevelID   int identity
        constraint PK_tblReferralLevel
            primary key
                with (fillfactor = 85),
    ReferralLevelName varchar(100)
)
go

create table dbo.tblReferral
(
    ReferralID              int identity
        constraint PK_tblReferral
            primary key
                with (fillfactor = 85),
    ClientID                int
        constraint FK_tblReferral_tblClient
            references dbo.tblClient,
    ReferralLevelID         int
        constraint FK_tblReferral_tblReferralLevel
            references dbo.tblReferralLevel,
    EligibilityDeterminedID int
        constraint FK_tblReferral_tblEligibiliyDetermined
            references dbo.tblEligibilityDetermined,
    BusinessIDReferredTo    int
        constraint FK_tblReferral_tblBusiness
            references dbo.tblBusiness
            on update cascade,
    ReferralDescription     varchar(300),
    ReferralDate            datetime,
    DateCreated             datetime,
    CreatedBy               int,
    DateModified            datetime,
    ModifiedBy              int,
    ProviderID              varchar(20)
)
go

create table dbo.tblEquipment
(
    EquipmentID            int identity
        constraint PK_tblEquipment
            primary key
                with (fillfactor = 85),
    EquipmentStatusID      int
        constraint FK_tblEquipment_tblEquipmentStatus
            references dbo.tblEquipmentStatus,
    EquipmentTypeID        int
        constraint FK_tblEquipment_tblEquipmentType
            references dbo.tblEquipmentType,
    ReferralID             int
        constraint FK_tblEquipment_tblReferral
            references dbo.tblReferral,
    DetailedDescription    varchar(300),
    AssetNumber            varchar(20),
    Quantity               int,
    NextMaintenanceDate    datetime,
    WarrantyDate           datetime,
    DestinationTypeID      int
        constraint FK_tblEquipment_tblDestinationType
            references dbo.tblDestinationType,
    DateCreated            datetime,
    CreatedBy              int,
    DateModified           datetime,
    ModifiedBy             int,
    ProviderID             varchar(20),
    BusinessIDModifiableBy int
        constraint FK_tblEquipment_tblBusiness
            references dbo.tblBusiness
            on update cascade
)
go

create index IX_DestinationTypeID
    on dbo.tblEquipment (DestinationTypeID)
    with (fillfactor = 85)
go

create index IX_EquipmentStatusID
    on dbo.tblEquipment (EquipmentStatusID)
    with (fillfactor = 85)
go

create index IX_EquipmentTypeID
    on dbo.tblEquipment (EquipmentTypeID)
    with (fillfactor = 85)
go

create index IX_ReferralID
    on dbo.tblEquipment (ReferralID)
    with (fillfactor = 85)
go

create table dbo.tblEquipmentBusinessAudit
(
    EquipmentBusinessAuditID int identity
        constraint PK_tblEquipmentBusinessHistory
            primary key
                with (fillfactor = 85),
    EquipmentID              int
        constraint FK_tblEquipmentBusinessHistory_tblEquipment
            references dbo.tblEquipment,
    BusinessIDFrom           int
        constraint FK_tblEquipmentBusinessHistory_tblBusiness
            references dbo.tblBusiness,
    BusinessIDTo             int
        constraint FK_tblEquipmentBusinessHistory_tblBusiness1
            references dbo.tblBusiness,
    DateCreated              datetime,
    CreatedBy                int
)
go

create index IX_BusinessIDFrom
    on dbo.tblEquipmentBusinessAudit (BusinessIDFrom)
    with (fillfactor = 85)
go

create index IX_BusinessIDTo
    on dbo.tblEquipmentBusinessAudit (BusinessIDTo)
    with (fillfactor = 85)
go

create index IX_EquipmentID
    on dbo.tblEquipmentBusinessAudit (EquipmentID)
    with (fillfactor = 85)
go

create table dbo.tblEquipmentProperty
(
    EquipmentPropertyID     int identity
        constraint PK_tblEquipmentProperty
            primary key
                with (fillfactor = 85),
    EquipmentTypePropertyID int
        constraint FK_tblEquipmentProperty_tblEquipmentTypeProperty
            references dbo.tblEquipmentTypeProperty,
    EquipmentID             int
        constraint FK_tblEquipmentProperty_tblEquipment
            references dbo.tblEquipment,
    PropertyValue           varchar(100),
    DateCreated             datetime,
    CreatedBy               int,
    DateModified            datetime,
    ModifiedBy              int
)
go

create index IX_EquipmentID
    on dbo.tblEquipmentProperty (EquipmentID)
    with (fillfactor = 85)
go

create index IX_EquipmentTypePropertyID
    on dbo.tblEquipmentProperty (EquipmentTypePropertyID)
    with (fillfactor = 85)
go

create table dbo.tblEquipmentStatusAudit
(
    EquipmentStatusAuditID int identity
        constraint PK_tblEquipmentStatusAudit
            primary key
                with (fillfactor = 85),
    EquipmentID            int
        constraint FK_tblEquipmentStatusAudit_tblEquipment
            references dbo.tblEquipment,
    EquipmentStatusIDFrom  int
        constraint FK_tblEquipmentStatusAudit_tblEquipmentStatus
            references dbo.tblEquipmentStatus,
    EquipmentStatusIDTo    int
        constraint FK_tblEquipmentStatusAudit_tblEquipmentStatus1
            references dbo.tblEquipmentStatus,
    DateCreated            datetime,
    CreatedBy              int
)
go

create index IX_EquipmentID
    on dbo.tblEquipmentStatusAudit (EquipmentID)
    with (fillfactor = 85)
go

create index IX_EquipmentStatusIDFrom
    on dbo.tblEquipmentStatusAudit (EquipmentStatusIDFrom)
    with (fillfactor = 85)
go

create index IX_EquipmentStatusIDTo
    on dbo.tblEquipmentStatusAudit (EquipmentStatusIDTo)
    with (fillfactor = 85)
go

create index IX_BusinessIDReferredTo
    on dbo.tblReferral (BusinessIDReferredTo)
    with (fillfactor = 85)
go

create index IX_ClientID
    on dbo.tblReferral (ClientID)
    with (fillfactor = 85)
go

create index IX_EligibilityDeterminedID
    on dbo.tblReferral (EligibilityDeterminedID)
    with (fillfactor = 85)
go

create index IX_ReferralLevelID
    on dbo.tblReferral (ReferralLevelID)
    with (fillfactor = 85)
go

create table dbo.tblReferralDisability
(
    ReferralDisabilityID  int identity
        constraint PK_ReferralDisability
            primary key
                with (fillfactor = 85),
    ReferralID            int
        constraint FK_tblReferralDisability_tblReferral
            references dbo.tblReferral,
    PrimaryDisability     bit,
    DisabilityCode        nvarchar(100),
    DisabilityDescription nvarchar(100)
)
go

create index IX_DisabilityCode
    on dbo.tblReferralDisability (DisabilityCode)
go

create index IX_ReferralID
    on dbo.tblReferralDisability (ReferralID)
    with (fillfactor = 85)
go

create table dbo.tblRegion
(
    RegionID          int identity
        constraint PK_tblDistrict
            primary key
                with (fillfactor = 85),
    RegionName        varchar(40),
    LoadingPercentage float,
    ZoneID            int
)
go

create table dbo.tblReportCategory
(
    ReportCategoryID   int not null
        constraint PK_tblReportCategory
            primary key
                with (fillfactor = 85),
    ReportCategoryName varchar(50)
)
go

create table dbo.tblReportObject
(
    ReportObjectID       int not null
        constraint PK_tblReportObject
            primary key
                with (fillfactor = 85),
    ReportDatabaseObject varchar(100),
    ReportFileName       varchar(100)
)
go

create table dbo.tblReport
(
    ReportID          int not null
        constraint PK_tblReport
            primary key
                with (fillfactor = 85),
    ReportName        varchar(300),
    ReportDescription varchar(2000),
    ReportObjectID    int
        constraint FK_tblReport_tblReportObject
            references dbo.tblReportObject
)
go

create index IX_ReportObjectID
    on dbo.tblReport (ReportObjectID)
    with (fillfactor = 85)
go

create table dbo.tblReportCategoryReport
(
    ReportCategoryReportID int identity
        constraint PK_tblReportCategoryReport
            primary key
                with (fillfactor = 85),
    ReportCategoryID       int
        constraint FK_tblReportCategoryReport_tblReportCategory
            references dbo.tblReportCategory
            on update cascade,
    ReportID               int
        constraint FK_tblReportCategoryReport_tblReport
            references dbo.tblReport
            on update cascade
)
go

create index IX_ReportCategoryID
    on dbo.tblReportCategoryReport (ReportCategoryID)
    with (fillfactor = 85)
go

create index IX_ReportID
    on dbo.tblReportCategoryReport (ReportID)
    with (fillfactor = 85)
go

create table dbo.tblReportParameter
(
    ReportParameterID          int not null
        constraint PK_tblReportParameter
            primary key
                with (fillfactor = 85),
    ReportParameterName        varchar(50),
    Caption1                   varchar(50),
    Caption2                   varchar(50),
    ReportParameterDescription varchar(100)
)
go

create table dbo.tblReportParameterReport
(
    ReportParameterReportID    int identity
        constraint PK_tblReportParameterReport
            primary key
                with (fillfactor = 85),
    ReportID                   int
        constraint FK_tblReportParameterReport_tblReport
            references dbo.tblReport
            on update cascade,
    ReportParameterID          int
        constraint FK_tblReportParameterReport_tblReportParameter
            references dbo.tblReportParameter
            on update cascade,
    ReportParameterDescription varchar(100)
)
go

create index IX_ReportID
    on dbo.tblReportParameterReport (ReportID)
    with (fillfactor = 85)
go

create index IX_ReportParameterID
    on dbo.tblReportParameterReport (ReportParameterID)
    with (fillfactor = 85)
go

create table dbo.tblReportParameterValueTemp
(
    ReportParameterValueTempID int identity
        constraint PK_tblReportParameterValueTemp
            primary key
                with (fillfactor = 85),
    ReportParameterValueID     bigint not null,
    ReportParameterID          int
        constraint FK_tblReportParameterValueTemp_tblReportParameter
            references dbo.tblReportParameter
            on update cascade,
    Value1                     varchar(200),
    Value2                     varchar(50)
)
go

create index IX_ReportParameterID
    on dbo.tblReportParameterValueTemp (ReportParameterID)
    with (fillfactor = 85)
go

create table dbo.tblRole
(
    RoleID          int identity
        constraint PK_tblUserLevel
            primary key
                with (fillfactor = 85),
    RoleName        varchar(50),
    RoleDescription varchar(200),
    Abbreviation    varchar(10)
)
go

create table dbo.tblBusinessEquipmentActionStatusRole
(
    BusinessEquipmentActionStatusRoleID int identity
        constraint PK_tblBusinessEquipmentStatusRole
            primary key
                with (fillfactor = 85),
    BusinessID                          int
        constraint FK_tblBusinessEquipmentActionStatusRole_tblBusiness
            references dbo.tblBusiness
            on update cascade,
    EquipmentActionStatusID             int
        constraint FK_tblBusinessEquipmentActionStatusRole_tblEquipmentActionStatus
            references dbo.tblEquipmentActionStatus
            on update cascade,
    RoleID                              int
        constraint FK_tblBusinessEquipmentActionStatusRole_tblRole
            references dbo.tblRole
)
go

create index IX_BusinessID
    on dbo.tblBusinessEquipmentActionStatusRole (BusinessID)
    with (fillfactor = 85)
go

create index IX_EquipmentActionStatusID
    on dbo.tblBusinessEquipmentActionStatusRole (EquipmentActionStatusID)
    with (fillfactor = 85)
go

create index IX_RoleID
    on dbo.tblBusinessEquipmentActionStatusRole (RoleID)
    with (fillfactor = 85)
go

create table dbo.tblMenuRole
(
    MenuRoleID int identity
        constraint PK_tblMenuRole
            primary key
                with (fillfactor = 85),
    MenuID     int
        constraint FK_tblMenuRole_tblMenu
            references dbo.tblMenu
            on update cascade,
    RoleID     int
        constraint FK_tblMenuRole_tblRole1
            references dbo.tblRole
)
go

create index IX_MenuID
    on dbo.tblMenuRole (MenuID)
    with (fillfactor = 85)
go

create index IX_RoleID
    on dbo.tblMenuRole (RoleID)
    with (fillfactor = 85)
go

create table dbo.tblPerson
(
    PersonID            int identity
        constraint PK_tblPersonID
            primary key
                with (fillfactor = 85),
    BusinessID          int
        constraint FK_tblUserAccount_tblBusiness
            references dbo.tblBusiness,
    FirstName           varchar(50),
    SurName             varchar(50),
    Address             varchar(100),
    Suburb              varchar(50),
    Postcode            varchar(10),
    PhoneNumber         varchar(20),
    EmailAddress        varchar(50),
    Username            varchar(15),
    UserPassword        varchar(50),
    PositionTitle       varchar(100),
    CeilingPriceLevelID int
        constraint FK_tblPerson_tblAuthorisationLevel
            references dbo.tblCeilingPriceLevel,
    LogonStatusID       int
        constraint FK_tblPerson_tblLoginStatus
            references dbo.tblLogonStatus,
    Retries             int,
    RoleIDForSession    int
        constraint FK_tblPerson_tblRole
            references dbo.tblRole,
    CAEPContact         bit,
    EMailSuscriber      bit,
    Comment             varchar(300),
    DateCreated         datetime,
    CreatedBy           int,
    DateModified        datetime,
    ModifiedBy          int,
    FTPAccess           bit,
    DSCSecureUsername   varchar(50),
    AccessRequestID     int,
    AccessRequestedBy   int,
    PrescriberOnly      bit
        constraint DF_tblPerson_Prescriber default 0 not null
)
go

create table dbo.tblEquipmentAction
(
    EquipmentActionID         int identity
        constraint PK_tblEquipmentAction
            primary key
                with (fillfactor = 85),
    EquipmentID               int
        constraint FK_tblEquipmentAction_tblEquipment
            references dbo.tblEquipment,
    ActionTypeID              int
        constraint FK_tblEquipmentAction_tblActionType
            references dbo.tblActionType,
    EquipmentActionStatusID   int
        constraint FK_tblEquipmentAction_tblEquipmentStatus
            references dbo.tblEquipmentActionStatus,
    EquipmentActionPriorityID int,
    SupplierName              varchar(100),
    OrderNumber               varchar(20),
    DateSpecified             datetime,
    DateExpected              datetime,
    Amount                    decimal(10, 2),
    DetailedDescription       varchar(100),
    TherapistID               int
        constraint FK_tblEquipmentAction_tblPerson
            references dbo.tblPerson,
    BusinessID                int,
    BusinessRank              int,
    DateCreated               datetime,
    CreatedBy                 int,
    DateModified              datetime
        constraint DF_tblEquipmentAction_DateModified default getdate(),
    ModifiedBy                int,
    ProviderID                varchar(20)
)
go

create index IX_ActionTypeID
    on dbo.tblEquipmentAction (ActionTypeID)
    with (fillfactor = 85)
go

create index IX_EquipmentActionStatusID
    on dbo.tblEquipmentAction (EquipmentActionStatusID)
    with (fillfactor = 85)
go

create index IX_EquipmentID
    on dbo.tblEquipmentAction (EquipmentID)
    with (fillfactor = 85)
go

create index IX_tblEquipmentActionDateCreated
    on dbo.tblEquipmentAction (DateCreated)
    with (fillfactor = 85)
go

create index IX_TherapistID
    on dbo.tblEquipmentAction (TherapistID)
    with (fillfactor = 85)
go

create index missing_index_321
    on dbo.tblEquipmentAction (EquipmentActionStatusID) include (EquipmentID, Amount)
    with (fillfactor = 85)
go

create index missing_index_945
    on dbo.tblEquipmentAction (DateSpecified) include (EquipmentID, ActionTypeID, EquipmentActionStatusID,
                                                       EquipmentActionPriorityID, Amount, BusinessRank)
    with (fillfactor = 85)
go

create table dbo.tblEquipmentActionBusinessCostCentre
(
    EquipmentActionBusinessCostCentreID int identity
        constraint PK_tblEquipmentInvoiceCostCentre
            primary key
                with (fillfactor = 85),
    EquipmentActionID                   int
        constraint FK_tblEquipmentActionBusinessCostCentre_tblEquipmentAction
            references dbo.tblEquipmentAction
            on delete cascade,
    BusinessCostCentreID                int
        constraint FK_tblEquipmentInvoiceCostCentre_tblBusinessCostCentre
            references dbo.tblBusinessCostCentre
            on update cascade,
    Amount                              decimal(10, 2),
    DateCreated                         datetime,
    CreatedBy                           int,
    DateModified                        datetime,
    ModifiedBy                          int
)
go

create index IX_BusinessCostCentreID
    on dbo.tblEquipmentActionBusinessCostCentre (BusinessCostCentreID)
    with (fillfactor = 85)
go

create index IX_EquipmentActionID
    on dbo.tblEquipmentActionBusinessCostCentre (EquipmentActionID)
    with (fillfactor = 85)
go

create index missing_index_1280
    on dbo.tblEquipmentActionBusinessCostCentre (BusinessCostCentreID) include (EquipmentActionID, Amount)
    with (fillfactor = 85)
go

create table dbo.tblEquipmentActionStatusAudit
(
    EquipmentActionStatusAuditID int identity
        constraint PK_EquipmentStatusHistory
            primary key
                with (fillfactor = 85),
    EquipmentActionID            int
        constraint FK_tblEquipmentActionStatusAudit_tblEquipmentAction
            references dbo.tblEquipmentAction
            on delete cascade,
    EquipmentActionStatusIDFrom  int
        constraint FK_tblEquipmentStatusHistory_tblEquipmentStatus
            references dbo.tblEquipmentActionStatus,
    EquipmentActionStatusIDTo    int
        constraint FK_tblEquipmentStatusHistory_tblEquipmentStatus1
            references dbo.tblEquipmentActionStatus,
    Amount                       decimal(10, 2),
    ConfirmationNumber           varchar(50),
    BusinessID                   int,
    DateCreated                  datetime,
    CreatedBy                    int
)
go

create index eCaepIndex75203
    on dbo.tblEquipmentActionStatusAudit (EquipmentActionStatusIDTo) include (EquipmentActionID, BusinessID, DateCreated)
    with (fillfactor = 85)
go

create index eCaepIndex75204
    on dbo.tblEquipmentActionStatusAudit (EquipmentActionStatusIDTo, DateCreated) include (EquipmentActionID, BusinessID)
    with (fillfactor = 85)
go

create index IX_EquipmentActionID
    on dbo.tblEquipmentActionStatusAudit (EquipmentActionID)
    with (fillfactor = 85)
go

create index IX_EquipmentActionStatusIDFrom
    on dbo.tblEquipmentActionStatusAudit (EquipmentActionStatusIDFrom)
    with (fillfactor = 85)
go

create index IX_EquipmentActionStatusIDTo
    on dbo.tblEquipmentActionStatusAudit (EquipmentActionStatusIDTo)
    with (fillfactor = 85)
go

create table dbo.tblInvoiceEquipmentAction
(
    InvoiceEquipmentActionID int identity
        constraint PK_tblEquipmentInvoice_1
            primary key
                with (fillfactor = 85),
    EquipmentActionID        int not null
        constraint FK_tblInvoiceEquipmentAction_tblEquipmentAction
            references dbo.tblEquipmentAction
            on delete cascade,
    InvoiceID                int
        constraint FK_tblInvoiceEquipmentAction_tblInvoice
            references dbo.tblInvoice
)
go

create index IX_EquipmentActionID
    on dbo.tblInvoiceEquipmentAction (EquipmentActionID)
    with (fillfactor = 85)
go

create index IX_InvoiceID
    on dbo.tblInvoiceEquipmentAction (InvoiceID)
    with (fillfactor = 85)
go

create index IX_BusinessID
    on dbo.tblPerson (BusinessID)
    with (fillfactor = 85)
go

create index IX_CeilingPriceLevelID
    on dbo.tblPerson (CeilingPriceLevelID)
    with (fillfactor = 85)
go

create index IX_LogonStatusID
    on dbo.tblPerson (LogonStatusID)
    with (fillfactor = 85)
go

create index IX_RoleIDForSession
    on dbo.tblPerson (RoleIDForSession)
    with (fillfactor = 85)
go

create table dbo.tblPersonLogonAudit
(
    PersonLogonAuditID int identity
        constraint PK_tblUserLoginHistory
            primary key
                with (fillfactor = 85),
    PersonID           int
        constraint FK_tblUserLoginHistory_tblPerson
            references dbo.tblPerson,
    IPAddress          varchar(20),
    LogonStatusID      int
        constraint FK_tblUserLoginHistory_tblLoginStatus
            references dbo.tblLogonStatus,
    RoleIDForSession   int
        constraint FK_tblPersonLogonAudit_tblRole
            references dbo.tblRole,
    DateCreated        datetime,
    CreatedBy          int
)
go

create index IX_LogonStatusID
    on dbo.tblPersonLogonAudit (LogonStatusID)
    with (fillfactor = 85)
go

create index IX_PersonID
    on dbo.tblPersonLogonAudit (PersonID)
    with (fillfactor = 85)
go

create index IX_RoleIDForSession
    on dbo.tblPersonLogonAudit (RoleIDForSession)
    with (fillfactor = 85)
go

create table dbo.tblReportRole
(
    ReportRoleID int identity
        constraint PK_tblReportRole
            primary key
                with (fillfactor = 85),
    RoleID       int
        constraint FK_tblReportRole_tblRole
            references dbo.tblRole,
    ReportID     int
        constraint FK_tblReportRole_tblReport
            references dbo.tblReport
            on update cascade
)
go

create index IX_ReportID
    on dbo.tblReportRole (ReportID)
    with (fillfactor = 85)
go

create index IX_RoleID
    on dbo.tblReportRole (RoleID)
    with (fillfactor = 85)
go

create table dbo.tblRolePerson
(
    RolePersonID int identity
        constraint PK_tblRolePerson
            primary key
                with (fillfactor = 85),
    PersonID     int
        constraint FK_tblRolePerson_tblPerson
            references dbo.tblPerson,
    RoleID       int
        constraint FK_tblRolePerson_tblRole
            references dbo.tblRole
)
go

create index IX_PersonID
    on dbo.tblRolePerson (PersonID)
    with (fillfactor = 85)
go

create index IX_RoleID
    on dbo.tblRolePerson (RoleID)
    with (fillfactor = 85)
go

create table dbo.tblTown
(
    TownID   int identity
        constraint PK_tblTown
            primary key
                with (fillfactor = 85),
    TownName varchar(40),
    PostCode varchar(4),
    RegionID int
        constraint FK_tblTown_tblRegion
            references dbo.tblRegion
)
go

create index IX_RegionID
    on dbo.tblTown (RegionID)
    with (fillfactor = 85)
go

create table dbo.tblTransactionCAEPType
(
    TransactionCAEPTypeID   int not null
        constraint PK_tblTransactionType
            primary key
                with (fillfactor = 85),
    TransactionCAEPTypeName varchar(50)
)
go

create table dbo.tblTransactionCAEPLog
(
    TransactionCAEPLogID  int identity
        constraint PK_tblTransaction
            primary key
                with (fillfactor = 85),
    BusinessAccountID     int
        constraint FK_tblTransaction_tblCostCentre
            references dbo.tblBusinessAccount,
    EquipmentActionID     int
        constraint FK_tblTransactionCAEPLog_tblEquipmentAction
            references dbo.tblEquipmentAction,
    TransactionCAEPTypeID int
        constraint FK_tblTransaction_tblTransactionType
            references dbo.tblTransactionCAEPType
            on update cascade,
    AmountDebit           decimal(10, 2),
    AmountCredit          decimal(10, 2),
    Narration             varchar(100),
    DateCreated           datetime,
    CreatedBy             int
)
go

create index eCaepIndex75201
    on dbo.tblTransactionCAEPLog (BusinessAccountID, TransactionCAEPTypeID, DateCreated) include (AmountDebit, AmountCredit)
    with (fillfactor = 85)
go

create index eCaepIndex75202
    on dbo.tblTransactionCAEPLog (BusinessAccountID, TransactionCAEPTypeID, DateCreated) include (AmountDebit, AmountCredit)
    with (fillfactor = 85)
go

create index IX_BusinessAccountID
    on dbo.tblTransactionCAEPLog (BusinessAccountID, TransactionCAEPTypeID)
    with (fillfactor = 85)
go

create index IX_EquipmentActionID
    on dbo.tblTransactionCAEPLog (EquipmentActionID)
    with (fillfactor = 85)
go

create index IX_TransactionCAEPTypeID
    on dbo.tblTransactionCAEPLog (TransactionCAEPTypeID)
    with (fillfactor = 85)
go

create index missing_index_35041
    on dbo.tblTransactionCAEPLog (EquipmentActionID, TransactionCAEPTypeID, AmountDebit, CreatedBy)
    with (fillfactor = 85)
go

