
# recording

Automates switching in/out of my recording workflow.
I run this just before clicking record, and I Ctrl+C after clicking stop recording

Perform the following:
1. Start OSKD

    This renders my keypresses to the screen for seeing vim combos

2. Increase font size in alacritty

    I perfer a smaller font size day to day, and always forget to change this, so increase this automatically

3. Swap Fish history to recording

    Use a separate fish history when recording, to resume on the same "page" when doing series

4. Open OBS Studio

    So I can then click record while having to run one program instead of two

The reverse is done when Ctrl+C is detected (kill OSKD, restore font, restore fish history, obs killed automatically on script exit)
