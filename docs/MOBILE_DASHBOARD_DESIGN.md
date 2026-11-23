# Mobile Super-App Dashboard — UI Design Specification

> Purpose: Build a mobile home screen that combines a functional **App Launcher** with an organizational **Information Hub**.
>
> Visual source of truth: Attach the approved dashboard reference image to the coding agent and ask it to match the composition closely. This document defines the design tokens, component behavior, and implementation requirements.

## 1. Design direction

- Product concept: Modern Corporate Super-App
- Style: clean, modern, friendly, professional, soft UI
- Primary font: **Inter**
- Alternative system font: SF Pro Display on Apple platforms; use a sensible sans-serif fallback elsewhere
- Background: very light blue-white
- Primary accent: royal blue
- Secondary accent: lavender/purple
- Cards: rounded corners, subtle borders and soft shadows
- Icons: consistent Lucide outline icons
- Layout: vertically scrollable, single-column home screen
- Navigation: fixed bottom navigation with safe-area support

Avoid dense enterprise-dashboard styling, dark backgrounds, excessive gradients, excessive decoration, and inconsistent icon styles.

## 2. Design tokens

### Colors

```css
:root {
  /* Primary */
  --color-primary: #2563EB;
  --color-primary-dark: #173B80;
  --color-primary-light: #E5EEFF;
  --color-sky-blue: #38BDF8;

  /* Secondary */
  --color-secondary: #7C3AED;
  --color-secondary-light: #EDE9FE;

  /* Surfaces */
  --color-background: #F5F8FF;
  --color-surface: #FFFFFF;
  --color-surface-secondary: #F0EBFF;

  /* Text */
  --color-text-primary: #142B55;
  --color-text-secondary: #64748B;
  --color-text-muted: #94A3B8;

  /* Semantic */
  --color-success: #16A34A;
  --color-warning: #F97316;
  --color-fundraising: #EC4899;
  --color-info: #2563EB;
  --color-border: #E5EAF5;
}
```

### Typography

Use Inter throughout the interface.

| Element | Size | Weight |
|---|---:|---|
| Greeting | 18px | 400 |
| User name | 26px | 700 |
| Section heading | 22px | 700 |
| Section subtitle | 13px | 400 |
| Card heading | 17px | 700 |
| Module label | 14px | 600 |
| Body text | 14px | 400 |
| Metadata | 12px | 500 |
| Button | 14px | 600 |

Suggested line heights:
- Headings: 120–130%
- Body: 145–150%
- Metadata: approximately 130%

### Spacing

Use an 8px-based spacing scale:
- 4px: extra small
- 8px: small
- 12px: medium-small
- 16px: medium
- 20px: large
- 24px: extra-large
- 32px: section spacing

### Border radius

- Small controls: 8px
- Buttons: 12px
- Module tiles: 18px
- Content cards: 18px
- Main section containers: 24px
- Avatar: fully circular

## 3. Home screen composition

Implement these sections in this order:

1. Header
2. Announcement banner
3. App Launcher
4. Information Hub
5. Fixed bottom navigation

The home screen scrolls vertically. The bottom navigation remains fixed and must not cover the last content item.

## 4. Components

### A. Header

Content:
- Circular user avatar, approximately 64–72px
- Greeting, e.g. “Good Morning,”
- User name displayed prominently
- Notification icon with unread-count badge
- Settings icon

Layout:
- Horizontal alignment
- Approximately 20px horizontal padding
- Greeting: 18px regular
- User name: 26px bold
- Icons aligned to the right

### B. Announcement banner

Purpose: Highlight a featured announcement or important organizational message.

Content example:
- Category: Announcement
- Title: “Safety First in Our Workplace”
- Description: “Let’s keep our workplace safe and healthy!”
- CTA: “Read More”

Appearance:
- Full width
- Approximately 190–210px tall
- 24px corner radius
- Blue gradient from `#1D4ED8` to `#38BDF8`
- White text
- Text aligned left
- Illustration aligned right
- Carousel indicators near the bottom

Support multiple announcement slides. Do not let the illustration obscure the text.

### C. App Launcher

Purpose: Provide shortcuts to functional applications only.

Header:
- Grid icon
- Title: “App Launcher”
- Subtitle: “Quick access to your applications”
- “See All” action

Example modules:
- Dashboard
- Permit
- Reports
- Campaigns
- Settings
- More Apps

Appearance:
- White or very light blue container
- Border: `1px solid #A7C7FF`
- Corner radius: 24px
- Padding: approximately 20px
- Responsive grid: 3 columns on narrow phones; 4 or 5 where space allows
- Each tile uses a colorful icon on a pale pastel background
- Icon size: approximately 32–40px
- Module label: 14px semibold
- Tile touch target should be at least 44px in both dimensions; aim for a comfortable 72–80px tile height

Example icon treatments:
- Dashboard: blue on `#EFF6FF`
- Permit: cyan on `#ECFEFF`
- Reports: purple on `#F5F3FF`
- Campaigns module: orange on `#FFF7ED`
- Settings: cyan on `#ECFEFF`
- More Apps: slate on `#F1F5F9`

Behavior:
- Each tile navigates to its corresponding application module.
- “See All” opens the complete module directory.
- Modules should be data-driven and filtered by the current user's permissions.
- Do not place event cards, fundraising updates, or announcements in this section.

### D. Information Hub

Purpose: Display organizational information and activities that users may want to read, attend, support, or join.

Header:
- Information icon
- Title: “Information Hub”
- Subtitle: “Stay updated with the latest news and activities”
- “See All” action

Appearance:
- Very light lavender section background: `#F0EBFF`
- 24px corner radius
- White content cards
- 18px card radius
- 8–12px spacing between cards

Support these content types:

#### 1. Upcoming Event
Display:
- Event title
- Date and time
- Location or meeting platform
- Optional image
- CTA: “View Details”

Suggested visual treatment:
- Date block on the left
- Event information in the middle
- CTA on the right when space permits
- Orange category badge: `#F97316`

#### 2. Fundraising
Display:
- Fundraising title
- Short description
- Current amount collected
- Target amount
- Progress bar
- CTA: “Donate”

Suggested visual treatment:
- Optional illustration or thumbnail
- Pink category badge: `#EC4899`
- Progress track in a pale pink/neutral tone
- Progress fill in `#EC4899`

#### 3. Organizational Campaign
Display:
- Campaign image or illustration
- Campaign title
- Short description
- Campaign period
- CTA: “Join Now”

Suggested visual treatment:
- Green category badge: `#16A34A`
- Image or illustration can appear beside or above the text depending on screen width

#### 4. Announcement / News
Display:
- Title
- Short description
- Publication date
- Optional image
- CTA: “Read More”

Suggested visual treatment:
- Blue category badge: `#2563EB`

Important:
- Use a reusable content-card system with layouts appropriate to each content type.
- Information Hub content must be dynamic and data-driven, ideally supplied by an API or CMS.
- Do not hardcode real event dates, fundraising amounts, or campaign claims. Use clearly identified sample data only when the backend is unavailable.
- “See All” opens a full Information Hub listing, with appropriate filters or categories.

### E. Bottom navigation

Items:
- Home
- Modules
- Notifications
- Profile

Appearance:
- Fixed at the bottom
- White background
- Subtle top border or shadow
- Four equally distributed items
- Icon size: approximately 24px
- Label size: 12px
- Active color: `#2563EB`
- Inactive color: `#64748B`
- Unread notification badge on Notifications
- Respect iOS and Android safe-area insets

## 5. UX and interaction requirements

- The home screen is vertically scrollable.
- Bottom navigation remains fixed.
- App Launcher tiles navigate to their respective modules.
- App Launcher “See All” opens the complete module directory.
- Information Hub “See All” opens the complete information listing.
- Event cards open event details.
- Fundraising cards open fundraising details.
- Campaign cards open campaign details.
- Announcement cards open announcement details.
- Notification icon opens notifications.
- Settings icon opens settings.
- All interactive elements have accessible labels and comfortable touch targets.
- Provide loading, empty, and error states for dynamic content.
- Avoid showing empty sections when no content is available; use a helpful empty state or hide the section according to product requirements.

## 6. Responsive behavior

Reference viewport: 390 × 844 CSS pixels.

Support small, standard, and large phones. Use responsive sizing rather than fixed screen dimensions.

Requirements:
- No horizontal overflow.
- Text wraps naturally.
- Cards resize appropriately.
- Grid column count adapts to available width.
- Images preserve their aspect ratio and use suitable cropping.
- Bottom navigation does not overlap scrollable content.
- Respect device safe areas.

## 7. Suggested component architecture

Adapt names and folders to the existing project conventions.

```text
src/
  components/
    home/
      HomeHeader
      AnnouncementCarousel
      AppLauncher
      AppModuleTile
      InformationHub
      EventCard
      FundraisingCard
      CampaignCard
      AnnouncementCard
      BottomNavigation
  theme/
    colors
    typography
    spacing
    shadows
```

Keep components reusable and keep design tokens separate from component styles.

## 8. Implementation workflow for the coding agent

Before changing code:

1. Inspect the existing project structure and identify the framework.
2. Identify the current routing, styling system, and component conventions.
3. Check which icon and UI libraries are already installed.
4. Check whether Inter is already available.
5. Identify existing APIs and data models that can supply modules and Information Hub content.
6. Do not replace existing architecture or introduce dependencies without a reason.

Then implement the screen using the existing stack.

After implementation:

1. Run the application.
2. Inspect it at a mobile viewport around 390 × 844.
3. Capture a screenshot.
4. Compare the screenshot with the supplied reference image.
5. Correct spacing, font sizes, colors, card proportions, alignment, and responsive behavior.
6. Verify navigation and card interactions.
7. Run available linting, tests, and build checks.

## 9. Final acceptance criteria

The implementation is complete when:
- App Launcher and Information Hub are visually and semantically distinct.
- App Launcher contains functional application shortcuts only.
- Information Hub contains events, fundraising, campaigns, and announcements.
- Typography, colors, spacing, and rounded-card styling follow this specification.
- The screen works on small and large mobile viewports.
- Bottom navigation respects safe areas.
- Interactive elements work.
- The application builds and runs successfully.

Do not redesign the concept or introduce a completely different visual direction. Use the supplied reference image as the visual source of truth and this document as the implementation specification.
