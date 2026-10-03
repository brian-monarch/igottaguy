# I Gotta Guy

### TL;DR

I Gotta Guy is a mobile-first, private neighborhood recommendation app for friends, family, and neighbors to find and share trusted contacts—from babysitters and plumbers to restaurants and kid activities. It replaces a difficult-to-maintain shared Google Sheet with structured profiles, referrals, ratings, reviews, pricing context, and search. The MVP prioritizes a small, invite-only community and simple contribution/retrieval workflows; AI-assisted enrichment and broader external review discovery are later-stage capabilities.

---

## Goals

### Business Goals

* Validate that a private, community-managed directory is more useful than the current shared Google Sheet for the initial network.
* Establish a reusable foundation for a community directory that can grow with the local network over time.
* Enable a lean, AI-assisted development workflow using Cursor and Grok bots.
* Metric baselines: Unknown.
* Metric targets: Unknown.

### User Goals

* Quickly find a trusted person, service, or local recommendation for a household need.
* Add a referral with enough structured detail for others to confidently act on it.
* Understand the recommender’s experience through ratings, comments, reviews, and pricing context.
* Access contact and website information from a mobile device with minimal effort.
* Discover recommendations across both household services and family-oriented local activities.

### Non-Goals

* Open, public marketplace listings or lead-generation for service providers in the MVP.
* Booking, payment processing, contracting, or dispute resolution in the MVP.
* Automated collection or publication of third-party reviews in the MVP.

---

## User Stories

* As a neighbor, I want to search or browse recommendations by category, so that I can quickly find help for a household or family need.
* As a neighbor, I want to view a contact’s referral details, contact methods, website, ratings, reviews, and pricing context, so that I can decide whether to reach out.
* As a neighbor, I want to add a new contact and referral, so that useful local knowledge is available to the community.
* As a neighbor, I want to submit a rating and written review for a contact I have used, so that I can share my experience.
* As a neighbor, I want to edit or remove my own contribution, so that I can correct outdated information.
* As an initial community administrator, I want to manage membership and moderate directory content, so that the directory remains private and trustworthy.

---

## Functional Requirements

* Access and community membership (Priority: P0)

  * Invite-only access: Users must be able to join the initial community through an invitation mechanism.
  * Authentication: Users must have an authenticated profile associated with their contributions.
  * Member identity: Display a contributor identity on referrals and reviews. Proposed: use name and optional profile image.
  * Administration: An administrator must be able to invite, remove, and manage members.

* Directory and discovery (Priority: P0)

  * Categories: Users must be able to browse contacts by category.
  * Initial category coverage: Support household and family needs, including babysitters, plumbers, landscapers, snow removal, roofers, appliance support, handymen, utilities, services, hobbies, restaurants, and kid activities.
  * Search: Users must be able to search contacts by name, category, and descriptive text.
  * Contact profiles: Each contact must have a dedicated profile page with available referral, contact, website, review, rating, and pricing information.
  * Proposed: allow a contact to belong to multiple categories.

* Referrals and contact management (Priority: P0)

  * Create contact: Members must be able to add a contact with a name, category, contact information, and optional website link.
  * Create referral: Members must be able to associate a recommendation with a contact.
  * Referral details: A referral must capture the contributor, recommendation text, and date submitted.
  * Edit contributions: Members must be able to edit or remove their own referrals and reviews.
  * Proposed: identify and resolve likely duplicate contact records before publishing a new record.

* Ratings, reviews, and price context (Priority: P0)

  * Ratings: Members must be able to provide a rating for a contact.
  * Reviews: Members must be able to provide written comments or reviews.
  * Pricing: Members must be able to share pricing information or pricing context.
  * Proposed: make pricing optional and support free-text context rather than enforcing a single pricing model.
  * Proposed: show an aggregate rating and review count on contact cards and profiles.

* Content trust and maintenance (Priority: P1)

  * Report content: Proposed: members can flag incorrect, inappropriate, or obsolete information for administrator review.
  * Recency: Proposed: display when a referral or review was submitted or last updated.
  * Moderation: Proposed: administrator approval is required for new contacts and edits during the initial launch.

* AI-assisted enrichment (Priority: P2)

  * Contact freshness: Proposed: AI-assisted workflows identify fields that may need verification, such as invalid websites or stale contact information.
  * Alternatives: Proposed: AI-assisted workflows suggest potential alternative providers or options for administrator review.
  * External review context: Proposed: AI-assisted workflows surface broader review information only after source, consent, attribution, legal, and quality requirements are defined.
  * No autonomous publishing: AI suggestions must not change or publish community data without human review.

## User Experience

**Entry Point & First-Time User Experience**

* A prospective member receives an invitation to join the private I Gotta Guy community.
* The member creates an account and completes a minimal profile.
* Proposed: the initial onboarding explains that recommendations are community-contributed, may become outdated, and should be independently verified before engaging a provider.
* The member lands on the mobile-first home screen with search, category browsing, and an obvious option to add a recommendation.

**Core Experience**

* Step 1: Find a recommendation.

  * The member searches by a need or browses category tiles.
  * Results show the contact name, category, aggregate rating when available, review count when available, and concise referral context.
  * Proposed: search results support filtering by category and sorting by relevance or rating.

* Step 2: Evaluate a contact.

  * The member opens a contact profile.
  * The profile presents contact information, website links, community referrals, ratings, reviews, and any shared pricing context.
  * Contact methods and website links are prominent and easy to use on a phone.
  * Proposed: a clear disclaimer identifies community-supplied information and encourages direct verification.

* Step 3: Add a contact or referral.

  * The member selects Add a Guy from the primary navigation.
  * The member searches existing contacts first, then either adds a referral to an existing profile or creates a new contact.
  * The form collects the required information and validates required fields before submission.
  * Proposed: a submission enters moderation review during the initial launch.

* Step 4: Share experience.

  * From a contact profile, the member selects rate or review.
  * The member submits a rating, written review, and optional pricing context.
  * The member can later update or remove their own contribution.

* Step 5: Maintain trust.

  * A member can flag information that appears wrong, unsafe, stale, or inappropriate.
  * An administrator reviews reported content and membership requests.

**Advanced Features & Edge Cases**

* A contact may serve several categories; the profile should support multiple classifications.
* A member may find duplicate records; Proposed: provide a report-duplicate path for administrator consolidation.
* A contact may have incomplete contact details; display only available information and avoid implying verification.
* Users must not be able to edit another member’s referral or review.
* Proposed: clear empty states help a user add the first recommendation in an underpopulated category.

**UI/UX Highlights**

* Mobile-first responsive design; prioritize one-handed navigation, large tap targets, readable cards, and fast scanning.
* Brand name: I Gotta Guy.
* Visual direction: clean, modern utility design with a warm community feel.
* Color system:
  * Background: Pale Fog Gray `#F4F6F4`
  * Surfaces/cards: Crisp White `#FFFFFF`
  * Primary text: Deep Slate `#1E2421`
  * Primary accent: Eucalyptus Sage `#3B7A57`
  * Secondary accent/links: Muted Denim Blue `#4A6FA5`
* Use accessible contrast, visible focus states, semantic labels, and keyboard support. Proposed: validate against WCAG 2.2 AA.
* Use concise, plain-language labels. “Add a Guy” may be a branded action, but the product must clearly support people, businesses, places, and activities of any type.

---

## Narrative

A parent hears that the family’s usual babysitter is unavailable for an upcoming evening. They remember that their neighborhood keeps recommendations in a Google Sheet, but finding a reliable option means scanning inconsistent rows, outdated contact details, and scattered comments. They need an answer quickly and want to know whether the recommendation came from someone they trust.

They open I Gotta Guy on their phone, search “babysitter,” and scan a small set of community-contributed profiles. One profile includes the sitter’s contact method, a website link when available, multiple referrals from familiar neighbors, ratings, and pricing context. The parent can decide whether to contact the sitter without leaving the app to decipher the spreadsheet.

Afterward, they add their own review and update the price context to help the next family. A neighbor later flags a stale phone number, and the community administrator can review it. Instead of relying on a static file that is difficult to maintain, the network has a simple, shared system for preserving local knowledge. The initial release stays deliberately narrow: help members find and contribute trusted recommendations. Over time, validated AI-assisted workflows may help identify records that need review and expand the directory responsibly.

---

## Success Metrics

### User-Centric Metrics

* Metric baselines: Unknown.
* Metric targets: Unknown.
* Proposed: active members who search, view a profile, or contribute during a defined measurement period.
* Proposed: successful-find rate, measured by a member viewing a contact profile after a search or category browse.
* Proposed: contribution rate, measured by contacts, referrals, ratings, reviews, and price entries submitted by members.
* Proposed: member-reported usefulness, collected through an optional in-product feedback prompt.

### Business Metrics

* Metric baselines: Unknown.
* Metric targets: Unknown.
* Proposed: reduction in reliance on the shared Google Sheet, measured through migration and member usage signals.
* Proposed: growth in the number of usable, community-contributed directory records.

### Technical Metrics

* Metric baselines: Unknown.
* Metric targets: Unknown.
* Proposed: mobile page load performance, availability, search response time, submission success rate, and application error rate.

### Tracking Plan

* Proposed events:
  * Invitation sent, accepted, and account created
  * Search submitted and category viewed
  * Search result selected and contact profile viewed
  * Contact created, referral submitted, rating submitted, review submitted, and pricing submitted
  * Contact information link clicked
  * Content flagged, moderation decision completed, and member removed
  * AI suggestion created, reviewed, accepted, or rejected

---

## Technical Considerations

### Technical Needs

* A mobile-first web application with authenticated access, responsive UI, search, directory profiles, and contribution forms.
* Core data entities: member, invitation, contact, category, referral, rating/review, price entry, report, moderation decision, and audit record.
* Support role-based authorization for members and administrators.
* Proposed: model contributions independently so each referral, review, and pricing entry retains attribution and can be edited by its author.
* Proposed: provide an import path to seed the directory from the current Google Sheet after data cleanup and field mapping.

### Integration Points

* Current source: Google Sheet containing shared contacts and recommendations.
* Website links and other contact information submitted by members.
* Proposed: authentication, transactional email/invitation, analytics, and hosting services to be selected during implementation.
* Proposed: AI tools, including Cursor and Grok bots, support development and future assisted workflows; they are not a substitute for application authorization, moderation, or data-quality controls.

### Data Storage & Privacy

* The application will store member-provided contact information, referrals, ratings, reviews, pricing context, and member contribution attribution.
* The directory is intended for a private network of neighbors, family, and friends; access controls must protect that boundary.
* Proposed: collect only information necessary for directory participation and display contributor identity only to authenticated community members.
* Proposed: establish retention, deletion, consent, and privacy-notice requirements before launch.
* Proposed: prohibit posting sensitive personal information about individuals without appropriate consent.

### Scalability & Performance

* Initial expected user load: Unknown.
* The initial architecture should support a small private community while allowing controlled growth in members, contacts, categories, and reviews.
* Proposed: design search and data models to support multi-category contacts and increasing directory volume without requiring a redesign.

### Potential Challenges

* Maintaining accuracy of community-contributed contact details and pricing information.
* Defining moderation standards for reviews, referrals, and sensitive personal information.
* Preventing duplicate contacts and misleading or low-quality contributions.
* Establishing appropriate sourcing, attribution, legal review, and quality controls before incorporating external review data.
* Dependencies: Unknown.

---

## Milestones & Sequencing

### Project Estimate

* Proposed estimate: Small, 1–2 weeks for a narrow MVP prototype; timing depends on the selected tooling, data migration effort, and authentication approach.
* Completion evidence: Unknown.

### Team Size & Composition

* Proposed: one builder using Cursor and Grok bots for implementation, with a small group of neighbors, family, and friends serving as early testers and contributors.
* Accountable role: Unknown.

### Suggested Phases

**Phase 0: Define and seed the directory (Proposed: 1–2 days)**

* Key deliverables: define MVP fields, categories, privacy rules, initial administrator, and a cleaned initial data set from the Google Sheet.
* Dependencies: access to the current Google Sheet and decisions on membership/privacy rules.

**Phase 1: Private directory MVP (Proposed: 3–7 days)**

* Key deliverables: invite-only access, mobile-first directory browsing and search, contact profiles, contact/referral creation, ratings, reviews, pricing context, and basic administration.
* Dependencies: selected application stack, authentication approach, and initial category taxonomy.

**Phase 2: Pilot and iterate (Proposed: 1–2 weeks)**

* Key deliverables: invite an initial group, collect feedback, correct data-quality issues, refine category/search behavior, and prioritize the next release.
* Dependencies: willing pilot members and defined feedback collection approach.

**Phase 3: Assisted maintenance (Proposed: after MVP validation)**

* Key deliverables: evaluate AI-assisted freshness checks, alternative suggestions, and review enrichment with human approval controls.
* Dependencies: validated MVP usage, approved data policy, and source/attribution requirements.