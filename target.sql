create table public.migrations
(
    id        serial
        primary key,
    migration varchar(255) not null,
    batch     integer      not null
);

alter table public.migrations
    owner to postgres;

create table public.cache
(
    key        varchar(255) not null
        primary key,
    value      text         not null,
    expiration integer      not null
);

alter table public.cache
    owner to postgres;

create table public.cache_locks
(
    key        varchar(255) not null
        primary key,
    owner      varchar(255) not null,
    expiration integer      not null
);

alter table public.cache_locks
    owner to postgres;

create table public.jobs
(
    id           bigserial
        primary key,
    queue        varchar(255) not null,
    payload      text         not null,
    attempts     smallint     not null,
    reserved_at  integer,
    available_at integer      not null,
    created_at   integer      not null
);

alter table public.jobs
    owner to postgres;

create index jobs_queue_index
    on public.jobs (queue);

create table public.job_batches
(
    id             varchar(255) not null
        primary key,
    name           varchar(255) not null,
    total_jobs     integer      not null,
    pending_jobs   integer      not null,
    failed_jobs    integer      not null,
    failed_job_ids text         not null,
    options        text,
    cancelled_at   integer,
    created_at     integer      not null,
    finished_at    integer
);

alter table public.job_batches
    owner to postgres;

create table public.failed_jobs
(
    id         bigserial
        primary key,
    uuid       varchar(255)                           not null
        constraint failed_jobs_uuid_unique
            unique,
    connection text                                   not null,
    queue      text                                   not null,
    payload    text                                   not null,
    exception  text                                   not null,
    failed_at  timestamp(0) default CURRENT_TIMESTAMP not null
);

alter table public.failed_jobs
    owner to postgres;

create table public.personal_access_tokens
(
    id             uuid default uuidv7() not null
        primary key,
    tokenable_type varchar(255)          not null,
    tokenable_id   uuid                  not null,
    name           varchar(255)          not null,
    token          varchar(64)           not null
        constraint personal_access_tokens_token_unique
            unique,
    abilities      text,
    last_used_at   timestamp(0),
    expires_at     timestamp(0),
    created_at     timestamp(0),
    updated_at     timestamp(0)
);

alter table public.personal_access_tokens
    owner to postgres;

create index personal_access_tokens_tokenable_type_tokenable_id_index
    on public.personal_access_tokens (tokenable_type, tokenable_id);

create table public.telescope_entries
(
    sequence                bigserial
        primary key,
    uuid                    uuid                 not null
        constraint telescope_entries_uuid_unique
            unique,
    batch_id                uuid                 not null,
    family_hash             varchar(255),
    should_display_on_index boolean default true not null,
    type                    varchar(20)          not null,
    content                 text                 not null,
    created_at              timestamp(0)
);

alter table public.telescope_entries
    owner to postgres;

create index telescope_entries_batch_id_index
    on public.telescope_entries (batch_id);

create index telescope_entries_family_hash_index
    on public.telescope_entries (family_hash);

create index telescope_entries_created_at_index
    on public.telescope_entries (created_at);

create index telescope_entries_type_should_display_on_index_index
    on public.telescope_entries (type, should_display_on_index);

create table public.telescope_entries_tags
(
    entry_uuid uuid         not null
        constraint telescope_entries_tags_entry_uuid_foreign
            references public.telescope_entries (uuid)
            on delete cascade,
    tag        varchar(255) not null,
    primary key (entry_uuid, tag)
);

alter table public.telescope_entries_tags
    owner to postgres;

create index telescope_entries_tags_tag_index
    on public.telescope_entries_tags (tag);

create table public.telescope_monitoring
(
    tag varchar(255) not null
        primary key
);

alter table public.telescope_monitoring
    owner to postgres;

create table public.roles
(
    id                    uuid    default uuidv7() not null
        primary key,
    auth_service_group_id varchar(255),
    name                  varchar(255)             not null
        constraint roles_name_unique
            unique,
    title                 varchar(255)             not null,
    description           varchar(255),
    strength              integer default 0        not null,
    status                "RoleStatus"             not null,
    created_at            timestamp(0),
    updated_at            timestamp(0)
);

alter table public.roles
    owner to postgres;

create index roles_status_index
    on public.roles (status);

create table public.users
(
    id                         uuid default uuidv7() not null
        primary key,
    role_id                    uuid                  not null
        constraint users_role_id_foreign
            references public.roles,
    first_name                 varchar(255),
    last_name                  varchar(255),
    email                      varchar(255)          not null
        constraint users_email_unique
            unique,
    password                   varchar(255),
    remember_token             varchar(100),
    auth_service               "AuthService"         not null,
    auth_service_id            varchar(255),
    avatar                     varchar(255),
    phone                      varchar(255),
    postcode                   varchar(255),
    address                    varchar(255),
    description                varchar(255),
    designation                varchar(255),
    invitation_token           varchar(255),
    status                     "UserStatus"          not null,
    approval_status            "UserApprovalStatus",
    reason                     varchar(255),
    email_verified_at          timestamp(0),
    invitation_token_expire_at timestamp(0),
    approved_at                timestamp(0),
    deactivated_at             timestamp(0),
    created_at                 timestamp(0),
    updated_at                 timestamp(0),
    creator_user_id            uuid
        constraint users_creator_user_id_foreign
            references public.users,
    inviter_user_id            uuid
        constraint users_inviter_user_id_foreign
            references public.users,
    approver_user_id           uuid
        constraint users_approver_user_id_foreign
            references public.users
);

alter table public.users
    owner to postgres;

create index users_role_id_index
    on public.users (role_id);

create index users_creator_user_id_index
    on public.users (creator_user_id);

create index users_inviter_user_id_index
    on public.users (inviter_user_id);

create index users_approver_user_id_index
    on public.users (approver_user_id);

create index users_auth_service_index
    on public.users (auth_service);

create index users_status_index
    on public.users (status);

create index users_approval_status_index
    on public.users (approval_status);

create table public.sessions
(
    id            varchar(255) not null
        primary key,
    user_id       uuid
        constraint sessions_user_id_foreign
            references public.users,
    ip_address    varchar(45),
    user_agent    text,
    payload       text         not null,
    last_activity integer      not null
);

alter table public.sessions
    owner to postgres;

create index sessions_user_id_index
    on public.sessions (user_id);

create index sessions_last_activity_index
    on public.sessions (last_activity);

create table public.password_reset_tokens
(
    email      varchar(255) not null
        primary key,
    token      varchar(255) not null,
    created_at timestamp(0)
);

alter table public.password_reset_tokens
    owner to postgres;

create table public.permission_modules
(
    id            uuid     default uuidv7()      not null
        primary key,
    name          varchar(255)                   not null
        constraint permission_modules_name_unique
            unique,
    title         varchar(255)                   not null,
    description   varchar(255),
    display_order smallint default '0'::smallint not null,
    created_at    timestamp(0),
    updated_at    timestamp(0)
);

alter table public.permission_modules
    owner to postgres;

create table public.permissions
(
    id                   uuid     default uuidv7()      not null
        primary key,
    permission_module_id uuid                           not null
        constraint permissions_permission_module_id_foreign
            references public.permission_modules
            on delete cascade,
    name                 varchar(255)                   not null
        constraint permissions_name_unique
            unique,
    title                varchar(255)                   not null,
    description          varchar(255),
    action               varchar(255)                   not null,
    strength             smallint default '1'::smallint not null,
    display_order        smallint default '0'::smallint not null,
    unallowed_roles      jsonb,
    created_at           timestamp(0),
    updated_at           timestamp(0),
    constraint permissions_permission_module_id_action_unique
        unique (permission_module_id, action)
);

alter table public.permissions
    owner to postgres;

create index permissions_permission_module_id_index
    on public.permissions (permission_module_id);

create index permissions_action_index
    on public.permissions (action);

create table public.role_permissions
(
    id              uuid    default uuidv7() not null
        primary key,
    role_id         uuid                     not null
        constraint role_permissions_role_id_foreign
            references public.roles
            on delete cascade,
    permission_id   uuid                     not null
        constraint role_permissions_permission_id_foreign
            references public.permissions
            on delete cascade,
    is_auto_granted boolean default false    not null,
    grantors        jsonb,
    created_at      timestamp(0),
    updated_at      timestamp(0),
    constraint role_permissions_role_id_permission_id_unique
        unique (role_id, permission_id)
);

alter table public.role_permissions
    owner to postgres;

create index role_permission_grantors_index
    on public.role_permissions using gin (grantors);

create index role_permissions_role_id_index
    on public.role_permissions (role_id);

create index role_permissions_permission_id_index
    on public.role_permissions (permission_id);

create table public.permission_dependent
(
    id                      uuid default uuidv7() not null
        primary key,
    permission_id           uuid                  not null
        constraint permission_dependent_permission_id_foreign
            references public.permissions
            on delete cascade,
    permission_dependent_id uuid                  not null
        constraint permission_dependent_permission_dependent_id_foreign
            references public.permissions
            on delete cascade,
    constraint permission_dependent_permission_id_permission_dependent_id_uniq
        unique (permission_id, permission_dependent_id)
);

alter table public.permission_dependent
    owner to postgres;

create index permission_dependent_permission_id_index
    on public.permission_dependent (permission_id);

create index permission_dependent_permission_dependent_id_index
    on public.permission_dependent (permission_dependent_id);

create table public.audit_trails
(
    id              uuid         default uuidv7()          not null
        primary key,
    auditable_id    uuid                                   not null,
    auditable_type  varchar(255)                           not null,
    action_type     "AuditActionType"                      not null,
    old_values      jsonb,
    new_values      jsonb,
    ip_address      inet,
    user_agent      varchar(255),
    metadata        jsonb,
    is_archived     boolean      default false             not null,
    created_at      timestamp(0) default CURRENT_TIMESTAMP not null,
    updater_user_id uuid
        constraint audit_trails_updater_user_id_foreign
            references public.users
);

alter table public.audit_trails
    owner to postgres;

create index audit_trails_auditable_id_auditable_type_index
    on public.audit_trails (auditable_id, auditable_type);

create index audit_trails_updater_user_id_index
    on public.audit_trails (updater_user_id);

create index audit_trails_action_type_index
    on public.audit_trails (action_type);

create table public.service_providers
(
    id              uuid    default uuidv7() not null
        primary key,
    name            varchar(255)             not null,
    description     text,
    email           varchar(255),
    phone           varchar(255),
    logo_url        varchar(255),
    address         varchar(255),
    suburb          varchar(255),
    postcode        varchar(255),
    is_sla_enabled  boolean default false    not null,
    is_specialist   boolean default false    not null,
    is_internal     boolean default false    not null,
    type            "ServiceProviderType"    not null,
    status          "ServiceProviderStatus"  not null,
    reason          varchar(255),
    created_at      timestamp(0),
    updated_at      timestamp(0),
    creator_user_id uuid
        constraint service_providers_creator_user_id_foreign
            references public.users,
    parent_id       uuid
        constraint service_providers_parent_id_foreign
            references public.service_providers
);

alter table public.service_providers
    owner to postgres;

create table public.user_service_provider
(
    id                  uuid default uuidv7() not null
        primary key,
    user_id             uuid                  not null
        constraint user_service_provider_user_id_foreign
            references public.users,
    service_provider_id uuid                  not null
        constraint user_service_provider_service_provider_id_foreign
            references public.service_providers,
    created_at          timestamp(0),
    updated_at          timestamp(0),
    creator_user_id     uuid
        constraint user_service_provider_creator_user_id_foreign
            references public.users,
    constraint user_service_provider_user_id_service_provider_id_unique
        unique (user_id, service_provider_id)
);

alter table public.user_service_provider
    owner to postgres;

create index user_service_provider_user_id_index
    on public.user_service_provider (user_id);

create index user_service_provider_creator_user_id_index
    on public.user_service_provider (creator_user_id);

create index user_service_provider_service_provider_id_index
    on public.user_service_provider (service_provider_id);

create index service_providers_creator_user_id_index
    on public.service_providers (creator_user_id);

create index service_providers_parent_id_index
    on public.service_providers (parent_id);

create index service_providers_type_index
    on public.service_providers (type);

create index service_providers_status_index
    on public.service_providers (status);

create table public.client_eligibility_criterias
(
    id              uuid    default uuidv7() not null
        primary key,
    name            varchar(255)             not null
        constraint client_eligibility_criterias_name_unique
            unique,
    description     varchar(255),
    is_active       boolean default true     not null,
    created_at      timestamp(0),
    updated_at      timestamp(0),
    creator_user_id uuid
        constraint client_eligibility_criterias_creator_user_id_foreign
            references public.users
);

alter table public.client_eligibility_criterias
    owner to postgres;

create index client_eligibility_criterias_creator_user_id_index
    on public.client_eligibility_criterias (creator_user_id);

create table public.client_eligibility_determineds
(
    id              uuid    default uuidv7() not null
        primary key,
    name            varchar(255)             not null
        constraint client_eligibility_determineds_name_unique
            unique,
    description     varchar(255),
    is_active       boolean default true     not null,
    created_at      timestamp(0),
    updated_at      timestamp(0),
    creator_user_id uuid
        constraint client_eligibility_determineds_creator_user_id_foreign
            references public.users
);

alter table public.client_eligibility_determineds
    owner to postgres;

create index client_eligibility_determineds_creator_user_id_index
    on public.client_eligibility_determineds (creator_user_id);

create table public.client_card_types
(
    id              uuid    default uuidv7() not null
        primary key,
    name            varchar(255)             not null
        constraint client_card_types_name_unique
            unique,
    description     varchar(255),
    is_active       boolean default true     not null,
    created_at      timestamp(0),
    updated_at      timestamp(0),
    creator_user_id uuid
        constraint client_card_types_creator_user_id_foreign
            references public.users
);

alter table public.client_card_types
    owner to postgres;

create index client_card_types_creator_user_id_index
    on public.client_card_types (creator_user_id);

create table public.clients
(
    id                               uuid    default uuidv7() not null
        primary key,
    service_provider_id              uuid                     not null
        constraint clients_service_provider_id_foreign
            references public.service_providers,
    client_eligibility_criteria_id   uuid
        constraint clients_client_eligibility_criteria_id_foreign
            references public.client_eligibility_criterias,
    client_eligibility_determined_id uuid
        constraint clients_client_eligibility_determined_id_foreign
            references public.client_eligibility_determineds,
    first_name                       varchar(255)             not null,
    last_name                        varchar(255)             not null,
    umrn                             varchar(255)
        constraint clients_umrn_unique
            unique,
    email                            varchar(255),
    phone                            varchar(255),
    description                      varchar(255),
    avatar_url                       varchar(255),
    dob                              date,
    address_line1                    varchar(255),
    address_line2                    varchar(255),
    suburb                           varchar(255),
    postcode                         varchar(255),
    client_number                    varchar(255),
    internal_reference_code          varchar(255),
    external_reference_code          varchar(255),
    has_card                         boolean default false    not null,
    gender                           "Gender"                 not null,
    indigenous_status                "IndigenousStatus"       not null,
    status                           "ClientStatus"           not null,
    transfer_history                 jsonb,
    reason                           varchar(255),
    created_at                       timestamp(0),
    updated_at                       timestamp(0),
    creator_user_id                  uuid
        constraint clients_creator_user_id_foreign
            references public.users
);

alter table public.clients
    owner to postgres;

create index clients_service_provider_id_index
    on public.clients (service_provider_id);

create index clients_client_eligibility_criteria_id_index
    on public.clients (client_eligibility_criteria_id);

create index clients_client_eligibility_determined_id_index
    on public.clients (client_eligibility_determined_id);

create index clients_creator_user_id_index
    on public.clients (creator_user_id);

create index clients_gender_index
    on public.clients (gender);

create index clients_indigenous_status_index
    on public.clients (indigenous_status);

create index clients_status_index
    on public.clients (status);

create table public.client_cards
(
    id                  uuid default uuidv7() not null
        primary key,
    client_card_type_id uuid
        constraint client_cards_client_card_type_id_foreign
            references public.client_card_types,
    client_id           uuid                  not null
        constraint client_cards_client_id_foreign
            references public.clients,
    card_number         varchar(255)          not null,
    issued_address      varchar(255),
    suburb              varchar(255),
    postcode            varchar(255),
    issued_date         date                  not null,
    expiry_date         date                  not null,
    created_at          timestamp(0),
    updated_at          timestamp(0),
    creator_user_id     uuid
        constraint client_cards_creator_user_id_foreign
            references public.users
);

alter table public.client_cards
    owner to postgres;

create index client_cards_client_card_type_id_index
    on public.client_cards (client_card_type_id);

create index client_cards_client_id_index
    on public.client_cards (client_id);

create index client_cards_creator_user_id_index
    on public.client_cards (creator_user_id);

create table public.referral_levels
(
    id              uuid     default uuidv7()      not null
        primary key,
    name            varchar(255)                   not null
        constraint referral_levels_name_unique
            unique,
    description     varchar(255),
    display_order   smallint default '1'::smallint not null,
    is_active       boolean  default true          not null,
    created_at      timestamp(0),
    updated_at      timestamp(0),
    creator_user_id uuid
        constraint referral_levels_creator_user_id_foreign
            references public.users
);

alter table public.referral_levels
    owner to postgres;

create index referral_levels_creator_user_id_index
    on public.referral_levels (creator_user_id);

create table public.referral_eligibilities
(
    id              uuid    default uuidv7() not null
        primary key,
    name            varchar(255)             not null,
    description     varchar(255),
    is_active       boolean default true     not null,
    created_at      timestamp(0),
    updated_at      timestamp(0),
    creator_user_id uuid
        constraint referral_eligibilities_creator_user_id_foreign
            references public.users
);

alter table public.referral_eligibilities
    owner to postgres;

create index referral_eligibilities_creator_user_id_index
    on public.referral_eligibilities (creator_user_id);

create table public.referrals
(
    id                             uuid    default uuidv7() not null
        primary key,
    client_id                      uuid                     not null
        constraint referrals_client_id_foreign
            references public.clients,
    referral_level_id              uuid                     not null
        constraint referrals_referral_level_id_foreign
            references public.referral_levels,
    referral_eligibility_id        uuid                     not null
        constraint referrals_referral_eligibility_id_foreign
            references public.referral_eligibilities,
    specialist_service_provider_id uuid
        constraint referrals_specialist_service_provider_id_foreign
            references public.service_providers,
    ref_num                        bigserial
        constraint referrals_ref_num_unique
            unique,
    description                    varchar(255),
    reason                         varchar(255),
    is_active                      boolean default true     not null,
    referred_at                    timestamp(0)             not null,
    created_at                     timestamp(0),
    updated_at                     timestamp(0),
    creator_user_id                uuid
        constraint referrals_creator_user_id_foreign
            references public.users
);

alter table public.referrals
    owner to postgres;

create index referrals_client_id_index
    on public.referrals (client_id);

create index referrals_referral_level_id_index
    on public.referrals (referral_level_id);

create index referrals_referral_eligibility_id_index
    on public.referrals (referral_eligibility_id);

create index referrals_specialist_service_provider_id_index
    on public.referrals (specialist_service_provider_id);

create index referrals_creator_user_id_index
    on public.referrals (creator_user_id);

create table public.equipment_categories
(
    id              uuid    default uuidv7() not null
        primary key,
    name            varchar(255)             not null,
    description     varchar(255),
    is_editable     boolean default true     not null,
    is_active       boolean default true     not null,
    created_at      timestamp(0),
    updated_at      timestamp(0),
    creator_user_id uuid
        constraint equipment_categories_creator_user_id_foreign
            references public.users
);

alter table public.equipment_categories
    owner to postgres;

create index equipment_categories_creator_user_id_index
    on public.equipment_categories (creator_user_id);

create table public.equipment_types
(
    id                    uuid    default uuidv7() not null
        primary key,
    equipment_category_id uuid                     not null
        constraint equipment_types_equipment_category_id_foreign
            references public.equipment_categories,
    name                  varchar(255)             not null,
    code                  varchar(255),
    description           varchar(255),
    max_quantity          integer,
    has_loading_cost      boolean default false    not null,
    can_therapist_view    boolean default false    not null,
    is_active             boolean default true     not null,
    created_at            timestamp(0),
    updated_at            timestamp(0),
    creator_user_id       uuid
        constraint equipment_types_creator_user_id_foreign
            references public.users,
    constraint equipment_types_equipment_category_id_name_unique
        unique (equipment_category_id, name)
);

alter table public.equipment_types
    owner to postgres;

create index equipment_types_equipment_category_id_index
    on public.equipment_types (equipment_category_id);

create index equipment_types_creator_user_id_index
    on public.equipment_types (creator_user_id);

create table public.equipment_deliverables
(
    id              uuid    default uuidv7() not null
        primary key,
    name            varchar(255)             not null,
    description     varchar(255),
    is_active       boolean default true     not null,
    created_at      timestamp(0),
    updated_at      timestamp(0),
    creator_user_id uuid
        constraint equipment_deliverables_creator_user_id_foreign
            references public.users
);

alter table public.equipment_deliverables
    owner to postgres;

create index equipment_deliverables_creator_user_id_index
    on public.equipment_deliverables (creator_user_id);

create table public.equipment
(
    id                       uuid    default uuidv7() not null
        primary key,
    referral_id              uuid                     not null
        constraint equipment_referral_id_foreign
            references public.referrals,
    equipment_type_id        uuid                     not null
        constraint equipment_equipment_type_id_foreign
            references public.equipment_types,
    equipment_deliverable_id uuid
        constraint equipment_equipment_deliverable_id_foreign
            references public.equipment_deliverables,
    ref_num                  bigserial
        constraint equipment_ref_num_unique
            unique,
    asset_code               varchar(255),
    description              varchar(255),
    external_reference_code  varchar(255),
    quantity                 integer                  not null,
    is_trial                 boolean default false    not null,
    status                   "EquipmentStatus"        not null,
    warranty_end_date        date,
    next_maintenance_date    date,
    created_at               timestamp(0),
    updated_at               timestamp(0),
    creator_user_id          uuid
        constraint equipment_creator_user_id_foreign
            references public.users
);

alter table public.equipment
    owner to postgres;

create index equipment_referral_id_index
    on public.equipment (referral_id);

create index equipment_equipment_type_id_index
    on public.equipment (equipment_type_id);

create index equipment_equipment_deliverable_id_index
    on public.equipment (equipment_deliverable_id);

create index equipment_creator_user_id_index
    on public.equipment (creator_user_id);

create index equipment_status_index
    on public.equipment (status);

create table public.equipment_ceiling_prices
(
    id                uuid          default uuidv7()     not null
        primary key,
    equipment_type_id uuid                               not null
        constraint equipment_ceiling_prices_equipment_type_id_foreign
            references public.equipment_types,
    min_price         numeric(8, 2) default '0'::numeric not null,
    max_price         numeric(8, 2) default '0'::numeric not null,
    is_gst_applicable boolean       default false        not null,
    action_type       "EquipmentActionType"              not null,
    created_at        timestamp(0),
    updated_at        timestamp(0),
    creator_user_id   uuid
        constraint equipment_ceiling_prices_creator_user_id_foreign
            references public.users
);

alter table public.equipment_ceiling_prices
    owner to postgres;

create index equipment_ceiling_prices_equipment_type_id_index
    on public.equipment_ceiling_prices (equipment_type_id);

create index equipment_ceiling_prices_creator_user_id_index
    on public.equipment_ceiling_prices (creator_user_id);

create index equipment_ceiling_prices_action_type_index
    on public.equipment_ceiling_prices (action_type);

create table public.equipment_actions
(
    id              uuid          default uuidv7()     not null
        primary key,
    equipment_id    uuid                               not null
        constraint equipment_actions_equipment_id_foreign
            references public.equipment,
    specifier_id    uuid
        constraint equipment_actions_specifier_id_foreign
            references public.users,
    supplier_name   varchar(255),
    order_code      varchar(255),
    description     varchar(255),
    invoice_number  varchar(255),
    invoice_url     varchar(255),
    price           numeric(8, 2) default '0'::numeric not null,
    gst             numeric(8, 2) default '0'::numeric not null,
    rank            integer,
    priority        "EquipmentActionPriority"          not null,
    type            "EquipmentActionType"              not null,
    status          "EquipmentActionStatus"            not null,
    requested_at    timestamp(0)                       not null,
    expected_at     timestamp(0),
    created_at      timestamp(0),
    updated_at      timestamp(0),
    creator_user_id uuid
        constraint equipment_actions_creator_user_id_foreign
            references public.users
);

alter table public.equipment_actions
    owner to postgres;

create index equipment_actions_equipment_id_index
    on public.equipment_actions (equipment_id);

create index equipment_actions_specifier_id_index
    on public.equipment_actions (specifier_id);

create index equipment_actions_creator_user_id_index
    on public.equipment_actions (creator_user_id);

create index equipment_actions_priority_index
    on public.equipment_actions (priority);

create index equipment_actions_type_index
    on public.equipment_actions (type);

create index equipment_actions_status_index
    on public.equipment_actions (status);

create table public.equipment_action_costs
(
    id                  uuid          default uuidv7()     not null
        primary key,
    equipment_action_id uuid                               not null
        constraint equipment_action_costs_equipment_action_id_foreign
            references public.equipment_actions,
    amount              numeric(8, 2) default '0'::numeric not null,
    cost_type           "EquipmentCostType"                not null,
    created_at          timestamp(0),
    updated_at          timestamp(0),
    creator_user_id     uuid
        constraint equipment_action_costs_creator_user_id_foreign
            references public.users
);

alter table public.equipment_action_costs
    owner to postgres;

create index equipment_action_costs_equipment_action_id_index
    on public.equipment_action_costs (equipment_action_id);

create index equipment_action_costs_creator_user_id_index
    on public.equipment_action_costs (creator_user_id);

create index equipment_action_costs_cost_type_index
    on public.equipment_action_costs (cost_type);

create table public.equipment_invoices
(
    id                  uuid          default uuidv7()     not null
        primary key,
    equipment_action_id uuid                               not null
        constraint equipment_invoices_equipment_action_id_foreign
            references public.equipment_actions,
    reference_code      varchar(255)                       not null,
    supplier_name       varchar(255)                       not null,
    invoice_url         varchar(255),
    amount              numeric(8, 2) default '0'::numeric not null,
    is_gst_included     boolean       default false        not null,
    invoiced_at         date                               not null,
    created_at          timestamp(0),
    updated_at          timestamp(0),
    creator_user_id     uuid
        constraint equipment_invoices_creator_user_id_foreign
            references public.users
);

alter table public.equipment_invoices
    owner to postgres;

create index equipment_invoices_equipment_action_id_index
    on public.equipment_invoices (equipment_action_id);

create index equipment_invoices_creator_user_id_index
    on public.equipment_invoices (creator_user_id);

create table public.budget_accounts
(
    id                  uuid    default uuidv7() not null
        primary key,
    service_provider_id uuid
        constraint budget_accounts_service_provider_id_foreign
            references public.service_providers,
    name                varchar(255)             not null,
    number              varchar(255)             not null
        constraint budget_accounts_number_unique
            unique,
    type                "BudgetAccountType"      not null,
    is_active           boolean default true     not null,
    is_system_account   boolean default false    not null,
    description         text,
    created_at          timestamp(0),
    updated_at          timestamp(0),
    creator_user_id     uuid                     not null
        constraint budget_accounts_creator_user_id_foreign
            references public.users
);

alter table public.budget_accounts
    owner to postgres;

create index budget_accounts_service_provider_id_index
    on public.budget_accounts (service_provider_id);

create index budget_accounts_creator_user_id_index
    on public.budget_accounts (creator_user_id);

create index budget_accounts_type_index
    on public.budget_accounts (type);

create table public.budget_years
(
    id               uuid           default uuidv7()     not null
        primary key,
    name             varchar(255)                        not null
        constraint budget_years_name_unique
            unique,
    start_date       date                                not null,
    end_date         date                                not null,
    description      text,
    total_budget     numeric(15, 2) default '0'::numeric not null,
    is_current       boolean        default false        not null,
    is_locked        boolean        default false        not null,
    rollover_enabled boolean        default false        not null,
    created_at       timestamp(0),
    updated_at       timestamp(0),
    creator_user_id  uuid
        constraint budget_years_creator_user_id_foreign
            references public.users
);

alter table public.budget_years
    owner to postgres;

create index budget_years_creator_user_id_index
    on public.budget_years (creator_user_id);

create table public.budget_pools
(
    id                  uuid           default uuidv7()     not null
        primary key,
    budget_account_id   uuid
        constraint budget_pools_budget_account_id_foreign
            references public.budget_accounts,
    budget_year_id      uuid                                not null
        constraint budget_pools_budget_year_id_foreign
            references public.budget_years,
    service_provider_id uuid
        constraint budget_pools_service_provider_id_foreign
            references public.service_providers,
    allocated_amount    numeric(15, 2) default '0'::numeric not null,
    available_amount    numeric(15, 2) default '0'::numeric not null,
    reserved_amount     numeric(15, 2) default '0'::numeric not null,
    spent_amount        numeric(15, 2) default '0'::numeric not null,
    expired_amount      numeric(15, 2) default '0'::numeric not null,
    transferred_in      numeric(15, 2) default '0'::numeric not null,
    transferred_out     numeric(15, 2) default '0'::numeric not null,
    is_system_pool      boolean        default false        not null,
    last_updated_at     timestamp(0)                        not null,
    created_at          timestamp(0),
    updated_at          timestamp(0)
);

alter table public.budget_pools
    owner to postgres;

create index budget_pools_budget_account_id_index
    on public.budget_pools (budget_account_id);

create index budget_pools_budget_year_id_index
    on public.budget_pools (budget_year_id);

create index budget_pools_service_provider_id_index
    on public.budget_pools (service_provider_id);

create table public.budget_allocations
(
    id                       uuid default uuidv7()    not null
        primary key,
    budget_year_id           uuid                     not null
        constraint budget_allocations_budget_year_id_foreign
            references public.budget_years,
    from_service_provider_id uuid
        constraint budget_allocations_from_service_provider_id_foreign
            references public.service_providers,
    to_service_provider_id   uuid                     not null
        constraint budget_allocations_to_service_provider_id_foreign
            references public.service_providers,
    type                     "BudgetAllocationType"   not null,
    distribution_type        "BudgetDistributionType",
    percentage               numeric(5, 2),
    amount                   numeric(15, 2)           not null,
    reference_code           varchar(255),
    status                   "BudgetAllocationStatus" not null,
    description              text,
    metadata                 jsonb,
    allocation_date          date                     not null,
    effective_from_date      date,
    effective_until_date     date,
    approved_at              timestamp(0),
    created_at               timestamp(0),
    updated_at               timestamp(0),
    creator_user_id          uuid                     not null
        constraint budget_allocations_creator_user_id_foreign
            references public.users
);

alter table public.budget_allocations
    owner to postgres;

create index budget_allocations_budget_year_id_index
    on public.budget_allocations (budget_year_id);

create index budget_allocations_from_service_provider_id_index
    on public.budget_allocations (from_service_provider_id);

create index budget_allocations_to_service_provider_id_index
    on public.budget_allocations (to_service_provider_id);

create index budget_allocations_creator_user_id_index
    on public.budget_allocations (creator_user_id);

create index budget_allocations_type_index
    on public.budget_allocations (type);

create index budget_allocations_status_index
    on public.budget_allocations (status);

create index budget_allocations_distribution_type_index
    on public.budget_allocations (distribution_type);

create table public.budget_reservations
(
    id                  uuid           default uuidv7()     not null
        primary key,
    budget_year_id      uuid                                not null
        constraint budget_reservations_budget_year_id_foreign
            references public.budget_years,
    service_provider_id uuid                                not null
        constraint budget_reservations_service_provider_id_foreign
            references public.service_providers,
    equipment_action_id uuid                                not null
        constraint budget_reservations_equipment_action_id_foreign
            references public.equipment_actions,
    amount              numeric(15, 2)                      not null,
    spent_amount        numeric(15, 2) default '0'::numeric not null,
    status              "BudgetReservationStatus"           not null,
    reference_code      varchar(255),
    metadata            jsonb,
    reserved_at         timestamp(0)                        not null,
    expires_at          timestamp(0),
    released_at         timestamp(0),
    spent_at            timestamp(0),
    created_at          timestamp(0),
    updated_at          timestamp(0),
    creator_user_id     uuid                                not null
        constraint budget_reservations_creator_user_id_foreign
            references public.users
);

alter table public.budget_reservations
    owner to postgres;

create index budget_reservations_budget_year_id_index
    on public.budget_reservations (budget_year_id);

create index budget_reservations_service_provider_id_index
    on public.budget_reservations (service_provider_id);

create index budget_reservations_equipment_action_id_index
    on public.budget_reservations (equipment_action_id);

create index budget_reservations_creator_user_id_index
    on public.budget_reservations (creator_user_id);

create index budget_reservations_status_index
    on public.budget_reservations (status);

create table public.budget_transactions
(
    id                       uuid    default uuidv7()     not null
        primary key,
    budget_year_id           uuid                         not null
        constraint budget_transactions_budget_year_id_foreign
            references public.budget_years,
    budget_allocation_id     uuid
        constraint budget_transactions_budget_allocation_id_foreign
            references public.budget_allocations,
    budget_reservation_id    uuid
        constraint budget_transactions_budget_reservation_id_foreign
            references public.budget_reservations,
    from_service_provider_id uuid
        constraint budget_transactions_from_service_provider_id_foreign
            references public.service_providers,
    to_service_provider_id   uuid
        constraint budget_transactions_to_service_provider_id_foreign
            references public.service_providers,
    amount                   numeric(15, 2)               not null,
    ref_num                  bigserial
        constraint budget_transactions_ref_num_unique
            unique,
    description              text,
    metadata                 jsonb,
    type                     "BudgetTransactionType"      not null,
    is_system_added          boolean default false        not null,
    effective_from_date      date    default CURRENT_DATE not null,
    transaction_at           date,
    created_at               timestamp(0),
    updated_at               timestamp(0),
    creator_user_id          uuid
        constraint budget_transactions_creator_user_id_foreign
            references public.users
);

alter table public.budget_transactions
    owner to postgres;

create index budget_transactions_budget_year_id_index
    on public.budget_transactions (budget_year_id);

create index budget_transactions_budget_allocation_id_index
    on public.budget_transactions (budget_allocation_id);

create index budget_transactions_budget_reservation_id_index
    on public.budget_transactions (budget_reservation_id);

create index budget_transactions_from_service_provider_id_index
    on public.budget_transactions (from_service_provider_id);

create index budget_transactions_to_service_provider_id_index
    on public.budget_transactions (to_service_provider_id);

create index budget_transactions_creator_user_id_index
    on public.budget_transactions (creator_user_id);

create index budget_transactions_type_index
    on public.budget_transactions (type);

create table public.budget_transaction_lines
(
    id                    uuid           default uuidv7()     not null
        primary key,
    budget_account_id     uuid                                not null
        constraint budget_transaction_lines_budget_account_id_foreign
            references public.budget_accounts,
    budget_transaction_id uuid                                not null
        constraint budget_transaction_lines_budget_transaction_id_foreign
            references public.budget_transactions,
    debit_amount          numeric(15, 2) default '0'::numeric not null,
    credit_amount         numeric(15, 2) default '0'::numeric not null,
    description           text,
    is_system_added       boolean        default false        not null,
    created_at            timestamp(0),
    updated_at            timestamp(0),
    creator_user_id       uuid
        constraint budget_transaction_lines_creator_user_id_foreign
            references public.users
);

alter table public.budget_transaction_lines
    owner to postgres;

create index budget_transaction_lines_budget_account_id_index
    on public.budget_transaction_lines (budget_account_id);

create index budget_transaction_lines_budget_transaction_id_index
    on public.budget_transaction_lines (budget_transaction_id);

create index budget_transaction_lines_creator_user_id_index
    on public.budget_transaction_lines (creator_user_id);

create table public.budget_transfers
(
    id                       uuid    default uuidv7() not null
        primary key,
    budget_year_id           uuid                     not null
        constraint budget_transfers_budget_year_id_foreign
            references public.budget_years,
    from_service_provider_id uuid                     not null
        constraint budget_transfers_from_service_provider_id_foreign
            references public.service_providers,
    to_service_provider_id   uuid                     not null
        constraint budget_transfers_to_service_provider_id_foreign
            references public.service_providers,
    amount                   numeric(15, 2)           not null,
    reference_code           varchar(255)             not null
        constraint budget_transfers_reference_code_unique
            unique,
    metadata                 jsonb,
    is_system_added          boolean default false    not null,
    type                     "BudgetTransferType"     not null,
    status                   "BudgetTransferStatus"   not null,
    requested_at             timestamp(0)             not null,
    approved_at              timestamp(0),
    processed_at             timestamp(0),
    created_at               timestamp(0),
    updated_at               timestamp(0),
    creator_user_id          uuid
        constraint budget_transfers_creator_user_id_foreign
            references public.users
);

alter table public.budget_transfers
    owner to postgres;

create index budget_transfers_budget_year_id_index
    on public.budget_transfers (budget_year_id);

create index budget_transfers_from_service_provider_id_index
    on public.budget_transfers (from_service_provider_id);

create index budget_transfers_to_service_provider_id_index
    on public.budget_transfers (to_service_provider_id);

create index budget_transfers_creator_user_id_index
    on public.budget_transfers (creator_user_id);

create index budget_transfers_type_index
    on public.budget_transfers (type);

create index budget_transfers_status_index
    on public.budget_transfers (status);

create table public.programs
(
    id              uuid    default uuidv7() not null
        primary key,
    name            varchar(255)             not null
        constraint programs_name_unique
            unique,
    description     varchar(255),
    is_active       boolean default true     not null,
    created_at      timestamp(0),
    updated_at      timestamp(0),
    creator_user_id uuid
        constraint programs_creator_user_id_foreign
            references public.users
);

alter table public.programs
    owner to postgres;

create index programs_creator_user_id_index
    on public.programs (creator_user_id);

create table public.disability_groups
(
    id              uuid    default uuidv7() not null
        primary key,
    name            varchar(255)             not null
        constraint disability_groups_name_unique
            unique,
    description     varchar(300),
    is_active       boolean default true     not null,
    created_at      timestamp(0),
    updated_at      timestamp(0),
    creator_user_id uuid
        constraint disability_groups_creator_user_id_foreign
            references public.users
);

alter table public.disability_groups
    owner to postgres;

create index disability_groups_creator_user_id_index
    on public.disability_groups (creator_user_id);

create table public.disability_types
(
    id                  uuid    default uuidv7() not null
        primary key,
    disability_group_id uuid                     not null
        constraint disability_types_disability_group_id_foreign
            references public.disability_groups,
    name                varchar(255)             not null,
    description         varchar(255),
    is_active           boolean default true     not null,
    created_at          timestamp(0),
    updated_at          timestamp(0),
    creator_user_id     uuid
        constraint disability_types_creator_user_id_foreign
            references public.users,
    constraint disability_types_disability_group_id_name_unique
        unique (disability_group_id, name)
);

alter table public.disability_types
    owner to postgres;

create index disability_types_disability_group_id_index
    on public.disability_types (disability_group_id);

create index disability_types_name_index
    on public.disability_types (name);

create index disability_types_creator_user_id_index
    on public.disability_types (creator_user_id);

create table public.disabilities
(
    id                 uuid    default uuidv7() not null
        primary key,
    referral_id        uuid                     not null
        constraint disabilities_referral_id_foreign
            references public.referrals,
    disability_type_id uuid                     not null
        constraint disabilities_disability_type_id_foreign
            references public.disability_types,
    description        varchar(255),
    is_active          boolean default true     not null,
    is_primary         boolean default false    not null,
    created_at         timestamp(0),
    updated_at         timestamp(0),
    creator_user_id    uuid
        constraint disabilities_creator_user_id_foreign
            references public.users
);

alter table public.disabilities
    owner to postgres;

create index disabilities_referral_id_index
    on public.disabilities (referral_id);

create index disabilities_disability_type_id_index
    on public.disabilities (disability_type_id);

create index disabilities_creator_user_id_index
    on public.disabilities (creator_user_id);

create table public.settings
(
    id                uuid    default uuidv7() not null
        primary key,
    retention_period  integer default 180      not null,
    next_retention_at timestamp(0),
    created_at        timestamp(0),
    updated_at        timestamp(0),
    creator_user_id   uuid
        constraint settings_creator_user_id_foreign
            references public.users
);

alter table public.settings
    owner to postgres;

create index settings_creator_user_id_index
    on public.settings (creator_user_id);

create table public.notes
(
    id              uuid         default uuidv7()          not null
        primary key,
    noteable_id     uuid                                   not null,
    noteable_type   varchar(255)                           not null,
    content         text                                   not null,
    metadata        jsonb,
    created_at      timestamp(0) default CURRENT_TIMESTAMP not null,
    creator_user_id uuid
        constraint notes_creator_user_id_foreign
            references public.users
);

alter table public.notes
    owner to postgres;

create index notes_noteable_id_noteable_type_index
    on public.notes (noteable_id, noteable_type);

create index notes_creator_user_id_index
    on public.notes (creator_user_id);

create table public.approval_types
(
    id                   uuid     default uuidv7()      not null
        primary key,
    name                 varchar(255)                   not null
        constraint approval_types_name_unique
            unique,
    code                 varchar(255)                   not null
        constraint approval_types_code_unique
            unique,
    description          varchar(255),
    entity_type          varchar(255),
    requires_multi_level boolean  default false         not null,
    max_approval_levels  smallint default '1'::smallint not null,
    is_active            boolean  default true          not null,
    created_at           timestamp(0),
    updated_at           timestamp(0)
);

alter table public.approval_types
    owner to postgres;

create table public.approval_workflows
(
    id                 uuid     default uuidv7()      not null
        primary key,
    approval_type_id   uuid                           not null
        constraint approval_workflows_approval_type_id_foreign
            references public.approval_types
            on delete cascade,
    name               varchar(255)                   not null,
    description        varchar(255),
    level              smallint default '1'::smallint not null,
    required_approvers smallint default '1'::smallint not null,
    display_order      smallint default '1'::smallint not null,
    is_active          boolean  default true          not null,
    created_at         timestamp(0),
    updated_at         timestamp(0),
    constraint approval_workflows_approval_type_id_level_unique
        unique (approval_type_id, level)
);

alter table public.approval_workflows
    owner to postgres;

create index approval_workflows_approval_type_id_index
    on public.approval_workflows (approval_type_id);

create index approval_workflows_name_index
    on public.approval_workflows (name);

create table public.approval_workflow_role
(
    id                   uuid default uuidv7() not null
        primary key,
    approval_workflow_id uuid                  not null
        constraint approval_workflow_role_approval_workflow_id_foreign
            references public.approval_workflows
            on delete cascade,
    role_id              uuid                  not null
        constraint approval_workflow_role_role_id_foreign
            references public.roles
            on delete cascade,
    constraint approval_workflow_role_approval_workflow_id_role_id_unique
        unique (approval_workflow_id, role_id)
);

alter table public.approval_workflow_role
    owner to postgres;

create index approval_workflow_role_approval_workflow_id_index
    on public.approval_workflow_role (approval_workflow_id);

create index approval_workflow_role_role_id_index
    on public.approval_workflow_role (role_id);

create table public.approvals
(
    id                       uuid     default uuidv7()      not null
        primary key,
    approval_type_id         uuid                           not null
        constraint approvals_approval_type_id_foreign
            references public.approval_types,
    approvable_type          varchar(255)                   not null,
    approvable_id            uuid                           not null,
    current_level            smallint default '1'::smallint not null,
    reason                   text,
    metadata                 jsonb,
    status                   "ApprovalStatus"               not null,
    submitted_at             timestamp(0)                   not null,
    escalated_at             timestamp(0),
    approved_at              timestamp(0),
    cancelled_at             timestamp(0),
    rejected_at              timestamp(0),
    expires_at               timestamp(0),
    created_at               timestamp(0),
    updated_at               timestamp(0),
    requester_user_id        uuid                           not null
        constraint approvals_requester_user_id_foreign
            references public.users,
    current_approver_user_id uuid
        constraint approvals_current_approver_user_id_foreign
            references public.users,
    escalated_user_id        uuid
        constraint approvals_escalated_user_id_foreign
            references public.users
);

alter table public.approvals
    owner to postgres;

create index approvals_approvable_type_approvable_id_index
    on public.approvals (approvable_type, approvable_id);

create index approvals_approval_type_id_index
    on public.approvals (approval_type_id);

create index approvals_requester_user_id_index
    on public.approvals (requester_user_id);

create index approvals_current_approver_user_id_index
    on public.approvals (current_approver_user_id);

create index approvals_escalated_user_id_index
    on public.approvals (escalated_user_id);

create index approvals_status_index
    on public.approvals (status);

create table public.approval_actions
(
    id              uuid    default uuidv7() not null
        primary key,
    approval_id     uuid                     not null
        constraint approval_actions_approval_id_foreign
            references public.approvals
            on delete cascade,
    user_id         uuid                     not null
        constraint approval_actions_user_id_foreign
            references public.users,
    description     text,
    reason          text,
    level           smallint                 not null,
    is_override     boolean default false    not null,
    type            "ApprovalActionType"     not null,
    action_taken_at timestamp(0)             not null,
    created_at      timestamp(0),
    updated_at      timestamp(0)
);

alter table public.approval_actions
    owner to postgres;

create index approval_actions_approval_id_index
    on public.approval_actions (approval_id);

create index approval_actions_user_id_index
    on public.approval_actions (user_id);

create index approval_actions_type_index
    on public.approval_actions (type);

create table public.approval_notifications
(
    id           uuid default uuidv7() not null
        primary key,
    approval_id  uuid                  not null
        constraint approval_notifications_approval_id_foreign
            references public.approvals
            on delete cascade,
    user_id      uuid                  not null
        constraint approval_notifications_user_id_foreign
            references public.users,
    message      text,
    channel      "NotificationChannel" not null,
    status       "NotificationStatus"  not null,
    scheduled_at timestamp(0),
    sent_at      timestamp(0),
    failed_at    timestamp(0),
    created_at   timestamp(0),
    updated_at   timestamp(0)
);

alter table public.approval_notifications
    owner to postgres;

create index approval_notifications_approval_id_index
    on public.approval_notifications (approval_id);

create index approval_notifications_user_id_index
    on public.approval_notifications (user_id);

create index approval_notifications_channel_index
    on public.approval_notifications (channel);

create index approval_notifications_status_index
    on public.approval_notifications (status);

create table public.approval_reminders
(
    id                    uuid     default uuidv7()      not null
        primary key,
    approval_id           uuid                           not null
        constraint approval_reminders_approval_id_foreign
            references public.approvals
            on delete cascade,
    user_id               uuid                           not null
        constraint approval_reminders_user_id_foreign
            references public.users,
    reminder_count        smallint default '0'::smallint not null,
    is_escalated          boolean  default false         not null,
    last_reminder_sent_at timestamp(0),
    next_reminder_at      timestamp(0),
    created_at            timestamp(0),
    updated_at            timestamp(0)
);

alter table public.approval_reminders
    owner to postgres;

create index approval_reminders_approval_id_index
    on public.approval_reminders (approval_id);

create index approval_reminders_user_id_index
    on public.approval_reminders (user_id);

create table public.info_types
(
    id          uuid    default uuidv7() not null
        primary key,
    name        varchar(255)             not null
        constraint info_types_name_unique
            unique,
    slug        varchar(255)             not null
        constraint info_types_slug_unique
            unique,
    description text,
    sort_order  integer default 0        not null,
    is_active   boolean default true     not null,
    created_at  timestamp(0),
    updated_at  timestamp(0)
);

alter table public.info_types
    owner to postgres;

create table public.info_tags
(
    id              uuid    default uuidv7() not null
        primary key,
    name            varchar(255)             not null
        constraint info_tags_name_unique
            unique,
    slug            varchar(255)             not null
        constraint info_tags_slug_unique
            unique,
    colour_name     varchar(255),
    colour_hex      varchar(255),
    is_active       boolean default true     not null,
    created_at      timestamp(0),
    updated_at      timestamp(0),
    creator_user_id uuid
        constraint info_tags_creator_user_id_foreign
            references public.users
);

alter table public.info_tags
    owner to postgres;

create index info_tags_creator_user_id_index
    on public.info_tags (creator_user_id);

create table public.info_items
(
    id                      uuid    default uuidv7() not null
        primary key,
    info_type_id            uuid
        constraint info_items_info_type_id_foreign
            references public.info_types,
    title                   varchar(255)             not null,
    description             text,
    cover_image             varchar(255),
    excerpt                 varchar(255),
    sort_order              integer default 0        not null,
    view_count              integer default 0        not null,
    reading_time            integer,
    status                  "InformationStatus"      not null,
    is_featured             boolean default false    not null,
    is_notification_enabled boolean default false    not null,
    assigned_date           date,
    published_at            timestamp(0),
    deactivated_at          timestamp(0),
    created_at              timestamp(0),
    updated_at              timestamp(0),
    author_user_id          uuid
        constraint info_items_author_user_id_foreign
            references public.users,
    creator_user_id         uuid
        constraint info_items_creator_user_id_foreign
            references public.users,
    publisher_user_id       uuid
        constraint info_items_publisher_user_id_foreign
            references public.users,
    deactivator_user_id     uuid
        constraint info_items_deactivator_user_id_foreign
            references public.users
);

alter table public.info_items
    owner to postgres;

create index info_items_info_type_id_index
    on public.info_items (info_type_id);

create index info_items_author_user_id_index
    on public.info_items (author_user_id);

create index info_items_creator_user_id_index
    on public.info_items (creator_user_id);

create index info_items_publisher_user_id_index
    on public.info_items (publisher_user_id);

create index info_items_deactivator_user_id_index
    on public.info_items (deactivator_user_id);

create index info_items_status_index
    on public.info_items (status);

create table public.info_item_tag
(
    id           uuid default uuidv7() not null
        primary key,
    info_item_id uuid                  not null
        constraint info_item_tag_info_item_id_foreign
            references public.info_items
            on delete cascade,
    info_tag_id  uuid                  not null
        constraint info_item_tag_info_tag_id_foreign
            references public.info_tags
            on delete cascade,
    constraint info_item_tag_info_item_id_info_tag_id_unique
        unique (info_item_id, info_tag_id)
);

alter table public.info_item_tag
    owner to postgres;

create index info_item_tag_info_item_id_index
    on public.info_item_tag (info_item_id);

create index info_item_tag_info_tag_id_index
    on public.info_item_tag (info_tag_id);

create table public.info_attachments
(
    id              uuid    default uuidv7() not null
        primary key,
    info_item_id    uuid                     not null
        constraint info_attachments_info_item_id_foreign
            references public.info_items
            on delete cascade,
    file_name       varchar(255),
    file_path       varchar(255)             not null,
    file_type       varchar(255)             not null,
    file_size       integer,
    file_hash       varchar(255),
    alt_text        varchar(255),
    caption         varchar(255),
    sort_order      integer default 0        not null,
    is_downloadable boolean default true     not null,
    created_at      timestamp(0),
    updated_at      timestamp(0),
    creator_user_id uuid
        constraint info_attachments_creator_user_id_foreign
            references public.users
);

alter table public.info_attachments
    owner to postgres;

create index info_attachments_info_item_id_index
    on public.info_attachments (info_item_id);

create index info_attachments_creator_user_id_index
    on public.info_attachments (creator_user_id);

create table public.info_item_role
(
    id           uuid default uuidv7() not null
        primary key,
    info_item_id uuid                  not null
        constraint info_item_role_info_item_id_foreign
            references public.info_items
            on delete cascade,
    role_id      uuid                  not null
        constraint info_item_role_role_id_foreign
            references public.roles
            on delete cascade,
    constraint info_item_role_info_item_id_role_id_unique
        unique (info_item_id, role_id)
);

alter table public.info_item_role
    owner to postgres;

create index info_item_role_info_item_id_index
    on public.info_item_role (info_item_id);

create index info_item_role_role_id_index
    on public.info_item_role (role_id);

create table public.notifications
(
    id              uuid                   default uuidv7()                      not null
        primary key,
    notifiable_type varchar(255)                                                 not null,
    notifiable_id   uuid                                                         not null,
    title           varchar(255)                                                 not null,
    description     text                                                         not null,
    priority        "NotificationPriority" default 'LOW'::"NotificationPriority" not null,
    action_url      text,
    metadata        jsonb,
    scheduled_at    timestamp(0),
    expires_at      timestamp(0),
    created_at      timestamp(0),
    updated_at      timestamp(0)
);

alter table public.notifications
    owner to postgres;

create index notifications_priority_index
    on public.notifications (priority);

create table public.notification_deliveries
(
    id              uuid                 default uuidv7()                        not null
        primary key,
    notification_id uuid                                                         not null
        constraint notification_deliveries_notification_id_foreign
            references public.notifications
            on delete cascade,
    user_id         uuid                                                         not null
        constraint notification_deliveries_user_id_foreign
            references public.users,
    channel         "NotificationChannel"                                        not null,
    status          "NotificationStatus" default 'PENDING'::"NotificationStatus" not null,
    failure_reason  text,
    sent_at         timestamp(0),
    delivered_at    timestamp(0),
    read_at         timestamp(0),
    created_at      timestamp(0),
    updated_at      timestamp(0)
);

alter table public.notification_deliveries
    owner to postgres;

create index notification_deliveries_notification_id_index
    on public.notification_deliveries (notification_id);

create index notification_deliveries_user_id_index
    on public.notification_deliveries (user_id);

create index notification_deliveries_channel_index
    on public.notification_deliveries (channel);

create index notification_deliveries_status_index
    on public.notification_deliveries (status);

create table public.notification_preferences
(
    id             uuid    default uuidv7() not null
        primary key,
    user_id        uuid                     not null
        constraint notification_preferences_user_id_foreign
            references public.users
            on delete cascade,
    web_enabled    boolean default true     not null,
    email_enabled  boolean default true     not null,
    sms_enabled    boolean default false    not null,
    dnd_start_time time(0),
    dnd_end_time   time(0),
    created_at     timestamp(0),
    updated_at     timestamp(0)
);

alter table public.notification_preferences
    owner to postgres;

create index notification_preferences_user_id_index
    on public.notification_preferences (user_id);

create table public.id_map
(
    source_table varchar(255) not null,
    source_id    varchar(255) not null,
    target_table varchar(255) not null,
    target_id    uuid         not null,
    migrated_at  timestamp with time zone default CURRENT_TIMESTAMP,
    primary key (source_table, source_id)
);

alter table public.id_map
    owner to postgres;

create index idx_id_map_target
    on public.id_map (target_table, target_id);

create table public.migration_log
(
    id                serial
        primary key,
    migration_name    varchar(255) not null,
    batch_id          varchar(100) not null,
    status            varchar(50)  not null,
    records_processed integer                  default 0,
    records_failed    integer                  default 0,
    error_message     text,
    started_at        timestamp with time zone default CURRENT_TIMESTAMP,
    completed_at      timestamp with time zone,
    metadata          jsonb,
    unique (migration_name, batch_id)
);

alter table public.migration_log
    owner to postgres;

create index idx_migration_log_status
    on public.migration_log (migration_name, status);

