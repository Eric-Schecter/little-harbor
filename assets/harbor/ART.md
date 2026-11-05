# Little Harbor artwork

Created with the built-in imagegen tool for this project on 2026-11-03. Assets are copied into the project; original generated files remain under the Codex generated_images directory.

- harbor.png: hand-painted cute medieval harbor background, elevated orthographic view, open turquoise battle water on the left, wooden wharf and cream-stone lighthouse/town on the right, no UI or ships.
- ships.png: transparent sprite sheet, two columns/two rows: red sail pirate boat, green sail rowing cutter, blue sail armored barge, burgundy two-mast pirate flagship. All facing right, honey wood and cream sails, matching camera and sunlight.
- towers.png: transparent three-column sprite sheet: left-facing ballista, stone catapult, fire-pot launcher, each on a round cream limestone platform, hand-painted honey wood and copper hardware.

Final tower edit prompt: “Background extraction only. Remove ALL white/off-white background from this 3-object sprite sheet and produce actual transparent alpha outside the three isolated weapons and their round stone bases, including all gaps in the wooden frameworks and between bow strings. Preserve the weapons, stone bases, colors, details, positions, three equal columns, and image dimensions exactly. No opaque white rectangles, no white backdrop, no checkerboard drawn into the image. Real clean transparency suitable for compositing onto turquoise water and wooden harbor. Do not redesign anything.”

Water glints, hull wakes, bobbing, recoil, projectiles, damage timing, sinking, floating debris, UI and pier extensions are drawn/animated in Godot. The ship sheet is sampled with custom row bounds to exclude neighboring mast flags.

## Q版更新

当前场景使用 `harbor-q.png`、`ships-q.png`、`towers-q.png`。船身更短胖、船长大头化、建筑圆润、细碎纹理减少，界面同步调整为奶油色圆角。全部使用内置 imagegen 生成；完整提示词见 `Q_STYLE_PROMPTS.md`。旧版素材作为同目录文件保留。新版船图集按等宽等高四格采样。

## Compact quay edit

`harbor-quay-q.png` is an edit of `harbor-q.png`, produced with built-in imagegen. The original is retained. Prompt: Preserve the cute elevated harbor, turquoise sea, upper-left islet, lighthouse, trees and right-side houses. Remove the continuous orange wooden boardwalk and large timber posts, replacing it with matching sea reaching approximately 75 percent of the canvas and a narrow rounded cream limestone quay. No ships, towers, text or UI; the game draws its own five small wooden tower platforms.

## Web cover

`cover-v1.png`: original OpenAI image-generation cover for Little Harbor, generated 2026-11-05. Cute rounded medieval pirate boats, ballista, catapult and lighthouse; cream LITTLE HARBOR title. Used by the Web launch card and its blurred background; excluded from the runtime PCK.
