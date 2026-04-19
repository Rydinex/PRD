# Design System Specification: High-Density Authority

## 1. Overview & Creative North Star
**Creative North Star: The Sovereign Observer**
This design system moves beyond the "standard dashboard" by treating data as high-end editorial content. It rejects the cluttered, "boxy" nature of traditional admin panels in favor of an authoritative, immersive environment. The experience is defined by **Tonal Architecture**—where depth is created through light and layering rather than structural lines.

By utilizing intentional asymmetry and a high-contrast typography scale, we transform a data-dense interface into a sophisticated command center that feels both secure and effortless. This is not just a tool; it is a premium workspace for high-stakes decision-making.

---

## 2. Color & Atmospheric Depth
Our palette is rooted in the `surface` (#111317), providing a deep, stable foundation that reduces eye strain during prolonged analytical sessions.

### The "No-Line" Rule
Traditional 1px solid borders are strictly prohibited for sectioning. Boundaries must be defined through background color shifts. Use `surface-container-low` for secondary areas and `surface-container-high` for elevated content. This creates a "molded" look where elements feel carved out of the interface rather than pasted onto it.

### Surface Hierarchy & Nesting
To create an "editorial" depth, we use a stacked-glass approach:
- **Level 0 (Base):** `surface` (#111317) for the main application background.
- **Level 1 (Sections):** `surface-container-low` (#1a1c20) for primary navigation or sidebar zones.
- **Level 2 (Content Cards):** `surface-container` (#1e2024) for the main data visualizations.
- **Level 3 (Interactive/Pop-overs):** `surface-container-highest` (#333539) for modals and dropdowns.

### The "Glass & Gradient" Rule
For high-priority call-to-actions (CTAs) or data highlights, use a subtle linear gradient transitioning from `primary_container` (#276ef1) to `primary` (#b1c5ff) at a 135-degree angle. Floating elements (like global search or tooltips) should utilize **Glassmorphism**: a 60% opacity fill of `surface_container_highest` with a `20px` backdrop-blur.

---

## 3. Typography: The Editorial Voice
We utilize a dual-typeface system to balance technical precision with authoritative elegance.

*   **Display & Headlines (Manrope):** Used for high-level metrics and page titles. The wide aperture of Manrope conveys modern transparency.
*   **Body & Labels (Inter):** Used for all data points, tables, and functional UI. Inter provides maximum legibility at high densities.

**Key Scales:**
- **Display-LG (3.5rem / Manrope):** For hero metrics (e.g., Total Portfolio Value).
- **Title-SM (1rem / Inter):** For card headers and section titles.
- **Label-SM (0.6875rem / Inter):** For micro-data, timestamps, and secondary metadata.

---

## 4. Elevation & Depth
Depth is achieved through **Tonal Layering** rather than traditional drop shadows.

### The Layering Principle
Instead of "lifting" an object with a shadow, "recess" the background. To highlight a specific card in a grid, change its background from `surface-container` to `surface-container-low`.

### Ambient Shadows
When a floating effect is required (e.g., a context menu), use an **Ambient Shadow**:
- **Color:** `on_surface` (#e2e2e8) at 4% opacity.
- **Blur:** 24px.
- **Spread:** -4px.
This mimics natural light dispersion in a dark environment, avoiding the "muddy" look of black shadows on dark backgrounds.

### The "Ghost Border" Fallback
If high-density data requires a hard separator, use a **Ghost Border**: `outline_variant` at 15% opacity. Never use 100% opaque lines.

---

## 5. Components & Data Structures

### Data Tables
*   **Structure:** No vertical or horizontal lines. Use `spacing-4` (0.9rem) vertical padding. 
*   **Row States:** On hover, shift background to `surface_container_high`.
*   **Sorting:** Use `primary` (#b1c5ff) for active sort icons to draw the eye without distracting.

### Buttons & Interaction
*   **Primary:** A gradient fill (Rydinex Blue to Primary Light) with `md` (0.375rem) roundedness.
*   **Secondary:** Ghost style. Transparent fill with a `Ghost Border` and `on_surface` text.
*   **Tertiary:** Text-only, using `primary_fixed_dim` for the label to indicate interactivity.

### Status Badges (The Semantic Pulse)
Badges should be understated. Use a desaturated background (10% opacity of the semantic color) with high-contrast text:
- **Success:** Background `on_success_container` @ 10%, Text `success_green`.
- **Danger:** Background `error_container` @ 10%, Text `error`.

### Sophisticated Inputs
Input fields should not be boxes. Use a "Bottom-Line Only" approach or a subtle `surface_container_lowest` fill. When focused, the bottom border animates from the center using the `primary_container` (#276ef1).

---

## 6. Do’s and Don’ts

### Do:
- **Embrace Negative Space:** Use `spacing-10` (2.25rem) between major modules to let the data breathe.
- **Use Intentional Asymmetry:** If a dashboard has three cards, make the primary metric card 66% width and the two secondary cards 33% stacked vertically to create a focal point.
- **Layer with Purpose:** Always ensure the most interactive element has the highest `surface-container` value.

### Don't:
- **Don't use pure black (#000):** It kills the "Glassmorphism" effect and feels "flat" rather than "premium." Use `surface` (#111317).
- **Don't use standard dividers:** If you need to separate content, use a 12px gap of the background color instead of a line.
- **Don't over-saturate:** Use Rydinex Blue sparingly. It is a "laser pointer," not a "paint bucket." Keep it for actions and active states only.