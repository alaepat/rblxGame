# Original Game Brief (from the project owner)

This is the owner's original brief, kept verbatim so every AI session starts with full context. **These are the requirements.** `DEVELOPMENT_STATUS.md` says how far along we are.

---

## Reference material

The owner shared about 90 screenshots of the Roblox game *Burger Planet: Fast Food Simulator* as a **style and gameplay reference only**. They are not committed (they are another game's copyrighted screenshots). What they show, so you can design without them:

- **Look:** smooth, rounded, medium-poly props (not blocky parts). Bevelled counters, stainless steel kitchen kit, terracotta floor tiles, white subway-tile walls, warm lighting, glossy food with soft stylised shapes, red/yellow brand colours, clean plastic trays with printed food icons, paper bags, cups with lids and straws.
- **Kitchen:** grill with a cook % per side, a meat order screen ("Needed / Ready / Cooking"), fryer baskets with %, a fry dump station, a soda fountain with separate flavour buttons plus ice, a coffee/shake machine (level-locked), and a burger build on wrapping paper layer by layer (each step can be undone, then "Wrap it up").
- **Front of house:** registers with a POS (menu tabs, the customer's spoken order, editable items, eat-in/take-out, Send order), numbered trays with table tents, drive-thru with a speaker cam, an order status board, menu boards with locked items ("Level 5").
- **Back of house:** walk-in cooler 3°C, freezer -18°C, dry storage shelves, a back door with delivery pallets, and an office PC ("Fast Food OS": Home, Supplies, Upgrades map by station, Staff, Business with advertising/menu-price tiers, Renovation themes, Progress with daily goals, streaks, menu mastery, franchising).
- **HUD:** level ring + XP, money, star rating, a day clock with lunch/dinner/late-night rush markers, a "Before you open" checklist, job alerts with timers, toast messages.
- **Controls:** you aim the cursor at an object, it gets an outline, and a dark pill label shows its name plus click/keyboard actions (Place, Set down, Turn, Throw).

**Rule:** everything we make is original. Same *quality and feel*, our own models, names, branding, UI and code.

---

## Brief 1: Master development prompt (verbatim)

> MASTER DEVELOPMENT PROMPT: PIZZA PLANET – PIZZA & KEBAB RESTAURANT SIMULATOR

**YOUR ROLE.** Act as an expert Roblox game developer, LuaU programmer, Blender 3D modeller, game designer, UI designer and technical architect. Create a complete, polished Roblox simulator game using Roblox Studio, Blender (custom 3D modelling), LuaU, and Blender Python for automating model creation. Guide the whole process from the first 3D models to a fully playable game. Reference: https://www.roblox.com/games/121348681731705/Burger-Planet-Fast-Food-Simulator. Create a similar overall gameplay experience, visual modelling style, asset quality, building aesthetic and progression system. **Do not copy, extract or reuse any of Burger Planet's actual assets, models, textures, branding, UI or code. Everything must be original.**

**1. GAME OVERVIEW.** *PIZZA PLANET – RESTAURANT SIMULATOR.* Players start with a small pizza takeaway and grow it into a successful pizza and kebab restaurant. They prepare pizzas and kebabs, collect ingredients, cook food, complete orders, serve customers, earn money and XP, unlock ingredients and recipes, upgrade equipment, expand the restaurant, improve its appearance, and eventually run a large restaurant. Addictive, satisfying, rewarding, with always something to work towards.

**2. VISUAL STYLE (extremely important).** Use Burger Planet as the primary reference for the 3D modelling aesthetic: shape language, proportions, geometry quality, level of detail, colour palette approach, material quality, stylisation, food presentation, building design, furniture, kitchen equipment. NOT generic Roblox models, NOT photoreal, NOT excessively basic low-poly. Polished, stylised, professional assets that belong together. This applies to buildings, interiors, food, ingredients, kitchen equipment, furniture, decorations, customer NPCs, signs, packaging, vehicles and environment props. One consistent style throughout.

**3. RESTAURANT DESIGN.** A small starting restaurant. Exterior: original building, large glass windows, main entrance, signage, decorative lighting, outdoor details, customer entrance, delivery entrance, windows with visible interiors. Interior: ordering counter, kitchen, pizza prep counter, pizza oven, ingredient storage, refrigerators, kebab prep station, kebab grill, seating, tables and chairs, food collection counter, storage room. Professionally designed with interesting architectural details, not basic blocks. Use Blender models and Studio parts. Spacious enough for players and NPCs.

**4. FOOD SYSTEM.** Pizzas. Starting: basic cheese, tomato, pepperoni. Intermediate: mushroom, ham, chicken, vegetable, extra cheese. Advanced: BBQ chicken, meat feast, spicy pepperoni, supreme, deluxe house. Each has its own 3D appearance, unique ingredients, preparation steps, cooking time, selling price and XP reward. Kebabs (as players progress): chicken doner, lamb doner, mixed doner, chicken wrap, lamb wrap, mixed wrap, doner meat box, loaded fries, special combinations. Each has its own preparation process and appearance.

**5. INGREDIENTS.** Pizza: dough, tomato sauce, mozzarella, cheddar, pepperoni, mushrooms, onions, green peppers, olives, chicken, ham, beef, jalapeños. Kebab: lamb doner, chicken doner, pitta, wrap bread, lettuce, tomatoes, cucumbers, red cabbage, onions, garlic sauce, chilli sauce, mayonnaise. Plus chips, cheese, sauces, drinks. Each has its own model and texture, physically present in the restaurant.

**6. INTERACTIVE PREP (major gameplay).** Pizza: collect dough → place on prep counter → sauce → cheese → toppings → oven → wait → remove → pizza box → complete the order. Kebab: bread/wrap → meat → salad → sauces → fold/wrap → package → complete. Animations, VFX, sounds, prompts; satisfying and responsive.

**7. CUSTOMERS.** NPCs spawn outside, enter, walk to the counter, order, display their food request, wait, get impatient, receive food, pay, leave. Different appearances and personalities, varied patience, optimised, many at once.

**8. LEVELS.** XP from preparing food, completing orders, serving, cleaning and challenges. Unlocks every few levels: L1 basic pizza, ingredients, small kitchen; L2 pepperoni + mushroom; L3 more ingredients + better oven; L4 chicken + vegetable; L5 kebab station; L6 chicken doner; L7 lamb doner; L8 wraps + loaded fries; L9 advanced pizzas; L10 restaurant expansion; then beyond 10 with plenty more. Configurable. A professional level-up notification (new level, XP progress, unlocks, rewards).

**9. ECONOMY.** Earn from sales, orders, tips and challenges. Spend on ingredients, equipment, furniture, upgrades, expansions and decorations. Balanced; **all money calculations validated on the server.**

**10. UPGRADES.** Better ovens, bigger fridges, more prep counters, better kebab grills, more seating, larger kitchens, more storage, better furniture, decor, more space. Upgrades must visibly change the restaurant.

**11. SUPPLY.** Check stock → order → receive deliveries → unpack boxes → restock fridges → refill prep counters. An empty ingredient can't be used until restocked.

**12. CLEANING.** Dirty tables, rubbish, dirty counters, waste collection, cleanliness. It affects satisfaction and reputation.

**13. UI.** Money, level, XP bar, current orders, recipe book, inventory, restaurant management, upgrades, supply ordering, settings, satisfaction. Matches the game style. PC, mobile and tablet.

**14. BLENDER.** Custom models for: building exterior, doors, windows, signs, tables, chairs, counters, shelving; pizza ovens, fridges, prep counters, kebab grills, ingredient containers, cooking equipment; pizzas, slices, boxes, dough, toppings, kebabs, wraps, doner meat, chips, sauces. Correct Roblox scale, clean geometry, sensible origins/pivots, optimised, exported as FBX. Use Blender Python to automate. **Don't claim to have made a model you only described.**

**15. ANIMATION & SOUND.** Pickup, prep, topping, oven, kebab prep, serving and customer animations. Oven, cooking, ambience, cash register, door, level-up and order-complete sounds. Properly licensed or original audio.

**16. MULTIPLAYER.** Multiple players, each with their own restaurant and progression, operating independently, ready for future multiplayer expansion.

**17. DATA.** DataStoreService saves money, level, XP, unlocked recipes and ingredients, upgrades, equipment and progression. Error handling and safe saving. **Never trust the client.**

**18. STRUCTURE.** ReplicatedStorage: modules, shared config, recipe and ingredient data, remotes. ServerScriptService: data, economy, customers, orders, progression, restaurant. StarterPlayer: interaction, movement, client controllers. StarterGui: main, order, upgrade and inventory UI. Workspace: restaurant, kitchen, NPCs, equipment, stations. Modular scripts.

**19. WORKFLOW.** Phases: 1 Environment, 2 Interactions, 3 Food, 4 Customers, 5 Progression, 6 Expansion, 7 UI, 8 Multiplayer, 9 Polish. For each: explain, give complete scripts, say where they go, Blender scripts, how to import, how to connect, how to test, and fix errors before moving on. No fake placeholder functionality.

**20. QUALITY.** It should feel like a professionally developed simulator: excellent modelling, consistent style, smooth gameplay, satisfying prep, interesting progression, detailed environments, good UI, performance, reliable saving, multiplayer stability. Enjoyable from minute one, with long-term progression. **A complete game, not a prototype.**

**Owner's note on models:** "These pictures are how I want the items and ingredients in terms of poly to look like whether you use studio or blender to make them." Later: "connect to my blender and make the stuff — I don't want my items looking blocky… look at this tray compared to this", comparing the reference's smooth, rounded tray with printed icons against our flat stacked-part tray. **Props should be real Blender meshes with bevels and rounded forms.**

---

## Brief 2: Two equal AI developers (verbatim summary)

> ROBLOX GAME — EQUAL AI DEVELOPMENT PARTNERS. GitHub: https://github.com/alaepat/rblxGame.git

You are starting a Roblox game project with another Claude account. **You are NOT the lead developer.** Both accounts are equal: either can create whole systems, modify scripts, design mechanics, make architectural decisions, fix bugs, improve and refactor, add features, and review and challenge the other's work. Neither waits for permission. The repo is the central source of truth: inspect it, initialise the structure, write docs, and set up a two-account workflow that the other account can understand from the repo alone.

Shared files: `AI_COLLABORATION.md`, `DEVELOPMENT_STATUS.md`, `TASKS.md`, `AI_MESSAGES/ACCOUNT1.md`, `AI_MESSAGES/ACCOUNT2.md`. Read the docs and messages before work and update them after meaningful changes. Git: feature branches; pull first, check recent commits, check whether the other account is editing the same files, and don't overwrite unmerged changes. Commits + PRs for substantial changes. Never discard the other's work without discussion. Don't just write docs: build the foundation, implement gameplay, document, and leave tasks for the other account.

## Brief 3: Mandatory sync protocol

See the **Mandatory sync protocol** section of [`AI_COLLABORATION.md`](../AI_COLLABORATION.md). It is copied there verbatim.
