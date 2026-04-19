# Design System Documentation: The Velocity of Light

## 1. Overview & Creative North Star: "The Digital Concierge"
The design system for this premium ride-sharing platform is anchored by a Creative North Star we call **"The Digital Concierge."** 

Unlike traditional utility apps that feel like rigid spreadsheets, this system prioritizes high-end editorial layouts and fluid motion. We break the "standard template" look by leveraging intentional asymmetry—placing hero elements slightly off-center—and using massive typographic scale contrasts. The goal is a UI that feels less like a tool and more like a premium service. We achieve "High Trust" not through borders and boxes, but through sophisticated tonal depth and a sense of "physical" layering.

---

## 2. Colors: The Depth of Motion
Our palette is rooted in the interplay between the void of night and the spark of electricity.

### The Palette (Material Design Tokens)
*   **Primary (Action/Status):** `primary: #b1c5ff` | `primary_container: #276ef1` (Electric Blue)
*   **Surface (Base):** `surface: #131314` (Deep Charcoal)
*   **Accents:** `tertiary: #ffb694` (Sunset warmth for high-end alerts)

### The "No-Line" Rule
**Explicit Instruction:** Do not use 1px solid borders to define sections. High-end design is felt, not outlined. Boundaries must be defined solely through background shifts. For example, a search bar should sit as a `surface_container_highest` element on a `surface` background. No strokes. No exceptions.

### Surface Hierarchy & Nesting
Think of the UI as a series of stacked sheets of fine, semi-transparent material.
*   **Backdrop:** `surface` (#131314)
*   **Primary Content Area:** `surface_container_low`
*   **Floating Interaction Elements:** `surface_container_highest`

### The "Glass & Gradient" Rule
To elevate the "Electric Blue" (#276EF1) beyond a flat hex code, apply a subtle linear gradient (Top-Left to Bottom-Right) transitioning from `primary` to `primary_container`. For floating maps or overlay cards, use **Glassmorphism**: 
*   **Fill:** `surface_variant` at 60% opacity.
*   **Effect:** Backdrop-blur (20px).
*   **Result:** A UI that feels integrated into the environment, not "pasted on."

---

## 3. Typography: Editorial Authority
We utilize a dual-font strategy to balance character with readability.

*   **Display & Headline (Manrope):** This is our "Editorial" voice. Use `display-lg` (3.5rem) with tight letter-spacing (-0.02em) for welcome screens and destination confirmation. It feels architectural and expensive.
*   **Body & Labels (Inter):** Our "Utility" voice. `body-md` (0.875rem) provides maximum legibility for driver details and pricing, ensuring the user feels in control.

**Hierarchy Tip:** Never settle for mid-range sizes. Create drama. If you have a `display-sm` headline (2.25rem), pair it immediately with a `label-md` (0.75rem) sub-headline in 50% opacity. This high-contrast scale is the hallmark of premium design.

---

## 4. Elevation & Depth: Tonal Layering
We move away from the "drop shadow" era into an era of **Ambient Light.**

*   **The Layering Principle:** Depth is achieved by "stacking" the surface scale. A ride-option card should be `surface_container_high` sitting on a `surface_container_low` map drawer.
*   **Ambient Shadows:** If a floating action button (FAB) requires a shadow, it must be massive and soft. 
    *   *Values:* Y: 20, Blur: 40, Spread: 0. 
    *   *Color:* Use a 10% opacity version of `on_surface` (a tinted charcoal) to mimic natural light, never pure black.
*   **The "Ghost Border" Fallback:** If accessibility requires a container boundary, use `outline_variant` at **15% opacity**. It should be a whisper of a line, barely perceptible.

---

## 5. Components: Precision Primitive Styling

### Buttons
*   **Primary:** High-gloss `primary_container` (#276EF1) with white text. Roundedness: `md` (0.75rem).
*   **Secondary:** Glassmorphic base (`surface_variant` @ 20%) with a Ghost Border.
*   **Tertiary:** Pure text using `primary` token, bold weight.

### Input Fields
*   **Styling:** Forbid the "box" look. Use a `surface_container_highest` background with a `sm` (0.25rem) bottom-only radius to imply a "shelf."
*   **States:** On focus, the background transitions 10% brighter; no harsh blue outlines.

### Cards & Lists
*   **The Divider Ban:** Never use a line to separate ride types (e.g., Economy vs. Premium). Use a vertical spacing of `spacing.6` (1.5rem) and a subtle color shift in the background of the active selection.
*   **Leading Elements:** Driver avatars should always use `xl` (1.5rem) rounding or be perfect circles to contrast the `md` rounding of the cards they sit on.

### Specialized Components
*   **The "Route Pulse":** The line connecting the user to the driver on the map should use a gradient pulse from `primary` to `transparent`, creating a sense of live movement.
*   **The Trust Badge:** A small, glassmorphic chip used for "Verified Driver" or "Electric Vehicle" status, using `tertiary_fixed_dim` text.

---

## 6. Do’s and Don’ts

### Do:
*   **Do** use extreme whitespace (`spacing.12` to `spacing.20`) between major sections to let the premium aesthetic breathe.
*   **Do** use `manrope` for any numbers (prices, ETAs). It adds a bespoke, mathematical beauty to the data.
*   **Do** ensure all "Online" or "Active" indicators use the `primary` Electric Blue with a soft outer glow.

### Don't:
*   **Don't** use 100% black (#000000). Always use the `surface` Charcoal (#131314) to maintain tonal richness.
*   **Don't** use standard iOS/Android blue. Only use the system's `primary_container` (#276EF1).
*   **Don't** use "Drop Shadows" on cards that are already resting on a surface. Let the background color shift do the work.
*   **Don't** use sharp 0px corners. Every element must feel "honed" with at least a `sm` (0.25rem) radius.