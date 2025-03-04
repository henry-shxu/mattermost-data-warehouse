{{config({
    "schema": "hightouch",
    "materialized": "view",
    "tags":["hourly","freemium"]
  })
}}
WITH existing_lead AS (
    SELECT
        lead.id,
        lead.email,
        lead.LEAD_SOURCE_TEXT__C,
        lead.LEAD_SOURCE_DETAIL__C,
        ROW_NUMBER() OVER (PARTITION BY lead.email ORDER BY lead.createddate DESC) as row_num
    FROM {{ ref('lead') }}
    WHERE converteddate IS NULL
), freemium_contacts_to_sync as (
    SELECT
        UUID_STRING('78157189-82de-4f4d-9db3-88c601fbc22e', customers_with_free_subs.email ) AS campaignmember_external_id,
        contact.id as contact_sfid,
        customers_with_free_subs.email,
        customers_with_free_subs.domain,
        customers_with_free_subs.last_name,
        customers_with_free_subs.company_name,
        existing_lead.id as existing_lead_id,
        'Trial Request' as most_recent_action,
        'Cloud Enterprise' as most_recent_action_detail,
        coalesce(existing_lead.LEAD_SOURCE_TEXT__C,'Referral') as lead_source,
        coalesce(existing_lead.LEAD_SOURCE_DETAIL__C,'Mattermost Cloud') as lead_source_detail
    FROM {{ ref('customers_with_cloud_free_subs') }} as customers_with_free_subs
    LEFT JOIN existing_lead ON customers_with_free_subs.email = existing_lead.email
    LEFT JOIN {{ ref('contact') }} ON customers_with_free_subs.email = contact.email
    WHERE contact.sfid is not null -- contact exists in salesforce
    AND sku = 'Cloud Enterprise' 
    AND previous_sku = 'Cloud Starter'
    AND customers_with_free_subs.status = 'trialing'
    AND customers_with_free_subs.hightouch_sync_eligible
)
SELECT * FROM freemium_contacts_to_sync