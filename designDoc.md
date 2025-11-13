**Design Language Brainstorm**

- **Core Theme:** Bright, high-energy, minimalist, and modern. Focus on speed and clarity.
- **Color Palette:**
    - **Primary:** Saturated, vibrant colors (e.g., electric blue, bright orange, neon green, magenta).
    - **UI Elements:** High-contrast for readability (e.g., white/cyan text on dark backgrounds).
    - **Numpad:** Buttons should be large, glossy, or flat-modern with distinct, bright colors for easy tapping.
- **Dynamic Background Animation:**
    - The main `VStack` background should dynamically animate its color based on the `carPosition` (timer progress).
    - **Start (0.0s):** A "calm" but bright color (e.g., bright sky blue).
    - **Mid-point (2.5s):** Transition through a "warning" color (e.g., intense yellow or orange).
    - **End (5.0s):** End on a "high-pressure" or "danger" color (e.g., deep red or magenta) as the timer expires.
    - This provides an ambient, full-screen visual cue for the time pressure, complementing the car animation.
- **Typography:**
    - Use a bold, clear, sans-serif font.
    - The font should be slightly rounded to feel more playful and less sterile.
    - Emphasize the problem (`6 x 7 = ?`) and the `userAnswer` with a large, heavy font weight.
- **Visual Feedback:**
    - **Correct:** Bright green flash, simple particle explosion (confetti), and a "ding" sound.
    - **Wrong / Time's Up:** Red flash, subtle screen shake effect, and a "buzz" or "crash" sound.fa