---
description: Write a blog post for a new feature based on the current branch changes
---

## Your task

Write a blog post announcing a new NewsBlur feature based on the changes in the current branch. The blog post should match NewsBlur's voice and style.

**Arguments provided:** {{ arguments }}

Use the arguments to determine:
- **Length**: short (2-3 paragraphs), medium (standard feature announcement), or long (in-depth with history/context)
- **Tone**: Any specific tone guidance (excited, technical, casual, etc.)
- **Focus**: Any specific aspects to emphasize

### Steps to execute

1. **Analyze the branch changes** to understand the feature:
   ```bash
   git log main..HEAD --oneline
   git diff main..HEAD --stat
   ```

   Then read the full diff to understand what was built:
   ```bash
   git diff main..HEAD
   ```

2. **Read the last 10 blog posts** to match the voice and style:
   ```bash
   ls -t blog/_posts/*.md | head -10
   ```

   Read each of these files to understand:
   - The conversational first-person voice
   - How features are introduced and explained
   - Screenshot placement and formatting
   - Section structure (headers, examples, etc.)
   - How posts end (forum link, availability info)

3. **Write the blog post** following these guidelines:

   **Front matter:**
   ```yaml
   ---
   layout: post
   title: <compelling title that describes the feature>
   tags: ["web"]  # or ["ios"], ["android"], or multiple
   ---
   ```

   **Voice and style:**
   - First-person conversational tone ("I wanted...", "You can now...")
   - Start with the problem or motivation, then introduce the solution
   - Be direct and practical, not marketing-speak
   - Include real examples of how to use the feature

   **Screenshots:**
   - Use placeholder comments where screenshots should go:
     ```html
     <!-- SCREENSHOT: description of what to capture -->
     <img src="/assets/FILENAME.png" style="width: 80%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">
     ```
   - Adjust width (50%, 60%, 80%, 90%, 100%) based on content
   - Screenshots should show the feature in action

   **Structure (for medium/long posts):**
   - Opening paragraph: Problem/motivation + solution announcement
   - "How it works" or "How to use it" section
   - Screenshots showing the feature
   - Real-world examples or use cases (if applicable)
   - Closing: Availability info + forum link for feedback

   **Filename format:**
   ```
   blog/_posts/YYYY-MM-DD-slug-title.md
   ```
   Use today's date and a URL-friendly slug.

4. **Create the blog post file** using the Write tool with the full content.

5. **Start the Jekyll server** to preview:
   ```bash
   make jekyll
   ```

   Report that Jekyll is running and the user can preview at http://localhost:4000

6. **Report what was created:**
   - The filename and path
   - The title
   - List of screenshot placeholders that need to be captured
   - Remind user to:
     - Take screenshots and save to `blog/assets/`
     - Update the placeholder image paths
     - Preview at http://localhost:4000
