pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
function _init()
    for i = 1, 16 do
        spawn_npc()
    end
    cartdata("gat8azizbgboss")

    game_title = true
    music(0)
end

function _update60()
    if game_title then
        if btnp(5) then
            game_title = false
            music(-1)
        end
    elseif alert then
        if btnp(5) and time() - alert_time > 1 then
            alert = nil
        end
    elseif active_menu then
        if btnp(2) then
            menu_choice -= 1
            if menu_choice < 1 then
                menu_choice = #menus[active_menu]
            elseif menu_choice > #menus[active_menu] then
                menu_choice = 1
            end
            sfx(1)
        elseif btnp(3) then
            menu_choice += 1
            if menu_choice < 1 then
                menu_choice = #menus[active_menu]
            elseif menu_choice > #menus[active_menu] then
                menu_choice = 1
            end
            sfx(1)
        elseif btnp(5) then
            menus[active_menu][menu_choice].func()
            sfx(1)
        elseif btnp(4) then
            active_menu = nil
            sfx(1)
        end
    elseif updateOverride then
        updateOverride()
    else
        local started_mission = false
        if not convo_active then
            if btn(0) then
                player.angle -= 0.1
            elseif btn(1) then
                player.angle += 0.1
            end

            if btn(2) then
                if player.speed == 0 then
                    player.speed = 0.05
                else
                    player.speed *= 1.05
                end

                if btn(4) then
                    -- sprint
                    if iswet(flr((player.x + 4) / tile_size), flr((player.y + 4) / tile_size)) then
                        player.speedcap = 0.5
                    else
                        player.speedcap = 1
                    end
                else
                    if iswet(flr((player.x + 4) / tile_size), flr((player.y + 4) / tile_size)) then
                        player.speedcap = 0.3
                    else
                        player.speedcap = 0.5
                    end
                end

                if player.speed > player.speedcap then
                    player.speed = player.speedcap
                end

                -- Only auto-align if the player isn't actively turning or shooting
                if not btn(0) and not btn(1) and not trail then
                    local target = round(player.angle % 8) % 8
                    local diff = ((target - player.angle + 4) % 8) - 4

                    if abs(diff) > 0.05 then
                        player.angle += sgn(diff) * 0.01
                    else
                        player.angle = target
                    end
                end
            elseif btn(3) then
                player.speed = -0.2
            else
                player.speed = 0
                if btnp(4) then
                    active_menu = 1
                end
            end

            move_player()
            update_mission_id()
        end

        if btnp(5) then
            if convo_active then
                convo_i += 1
                if convo_i > #missions[convo_mission_id].convo then
                    convo_active = false
                    if missions[convo_mission_id].on_start then
                        missions[convo_mission_id].on_start()
                    end
                    active_mission = convo_mission_id
                    started_mission = true
                end
            else
                local talk_id = get_mission_in_range()
                mission_id = talk_id
                if talk_id then
                    convo_active = true
                    convo_mission_id = talk_id
                    convo_i = 1
                else
                    -- pew pew
                    if player.ammo > 0 then
                        player.ammo -= 1
                        spawn_bullet()
                        sfx(0)
                        lastshot = time()

                        -- scare the bitch ass NPCs in a 10-tile radius
                        for i = 1, #npcs do
                            if isinrange(npcs[i].x + 4, npcs[i].y + 4, 10) then
                                npcs[i].scared = time()
                                npcs[i].target = nil
                            end
                        end
                    end
                end
            end
        end

        if time() - lastshot < 5 or options.aiming then
            -- show trajectory
            if player.ammo > 0 then
                trail = true
            end
        else
            trail = false
        end

        move_projectiles()
        move_npcs()
        move_particles()
        if not started_mission then
            check_missions()
        end
    end
end

function _draw()
    cls()
    if game_title then
        draw_title()
    elseif alert then
        draw_alert()
    elseif convo_active then
        draw_convo()
    elseif active_menu then
        draw_menu()
    else
        draw_map()
        draw_player()
        draw_missions()
        draw_projectiles()
        show_trail()
        draw_npcs()
        draw_particles()
        draw_items()

        show_notices()
        show_stats()
        if options.debug then
            show_debug()
        end
    end
end

-->8
version = "0.1alpha"
map_width, map_height = 32, 32
screen_width, screen_height = 128, 128
tile_size = 8

scrollx, scrolly = 0, 0

options = {
    aiming = false,
    debug = false
}

menus = {
    {
        {
            title = "save game",
            desc = "save your progress for later sessions",
            func = function()
                save_game()
            end
        },
        {
            title = "load game",
            desc = "load your progress from a previous save, you'll lose unsaved changes",
            func = function()
                load_game()
            end
        },
        {
            title = "options",
            desc = "show gameplay options",
            func = function()
                active_menu = 2
                menu_choice = 1
            end
        }
    },
    {
        {
            get_title = function() return "aiming: " .. (options.aiming and "on" or "off") end,
            get_desc = function()
                if options.aiming then
                    return "always show the aiming trajectory, diables auto-guiding"
                else
                    return "show the aiming trajectory for 5 seconds after you shoot then re-enables auto-guiding"
                end
            end,
            func = function() options.aiming = not options.aiming end
        },
        {
            title = "advanced",
            desc = "show advanced options",
            func = function()
                active_menu = 3
                menu_choice = 1
            end
        }
    },
    {
        {
            get_title = function() return "debug: " .. (options.debug and "on" or "off") end,
            get_desc = function()
                if options.debug then
                    return "show debug info"
                else
                    return "hide debug info"
                end
            end,
            func = function() options.debug = not options.debug end
        }
    }
}

alert = nil
alert_time = 0

active_menu = nil
menu_choice = 1

trail = false
lastshot = 0

notice = nil
noticetime = 0

tip = nil
tiptime = 0
tips = {
    { text = "tip: you can either fire a shot to enable aiming or do it in the options menu (press 🅾️ while standing)." }
}

button_notice = nil

active_mission = nil
mission_id = nil
convo_active = false
convo_mission_id = nil
convo_i = 1

face = {
    jeremy = 192,
    jeremy_angry = 224,
    kenlee = 194,
    kenlee_robot = 226,
    sign = 196,
    kenlao = 228,
    generic_workman = 230,
    sloppy = 198,
    shakira = 200,
    sonny = 202
}

missions = {
    {
        x = 8 * 15, y = 8 * 5, sprite = 54, name = "a deal with the devil...",
        convo = {
            { 194, "こんにちは..." },
            { 192, "what?" },
            { 194, "あなたのおちん-" },
            { 192, "what the fuck?" },
            { 194, "jeremy, i am master ken-lee, i need you to kill slippy, the leader of the most dangerous gang in chinatown..." },
            { 192, "bro why the hell would i do that?" },
            { 194, "because we need to take over chinatown and make it japantown... and also because i can't come up with a good story for the game so will start from here" },
            { 192, "ok old man, arigato later." },
            { 194, "you mean さようなら?" },
            { 192, "shut your bitch ass up." }
        },
        on_start = function()
            set_notice("slippy is infiltrating the citizens, find him and kill him! +120●")
            set_tip(1)
            player.ammo += 120
            spawn_npc("slippy")
        end,
        to_end = function()
            for i = 1, #npcs do
                if npcs[i].name == "slippy" and npcs[i].health <= 0 then
                    return true
                end
            end
            return false
        end,
        on_end = function()
            set_notice("mission complete! +100$")
            player.money += 100
        end
    },
    {
        x = 8 * 15, y = 8 * 5, sprite = 54, name = "the next operation...", missions_needed = { 1 },
        convo = {
            { 194, "hello again..." },
            { 192, "that was some crazy shit, old man. now would you consider fucking off?" },
            { 194, "i am a man of honor, i will not." },
            { 192, "what the fuck does honor have to do with this?" },
            { 194, "i am a man of honor, i will not." },
            { 192, "what the hell is wrong with you, ken-lee?" },
            { 194, "i am a man of honor, i will not." },
            { 224, "shut the fuck up! (punches ken-lee in the face)" },
            {
                nil, nil,
                function()
                    if not stamp then
                        stamp = time()
                        sfx(0)
                    end
                    if time() - stamp < 1 then
                        if time() % 0.2 < 0.1 then
                            rectfill(0, 0, screen_width, screen_height, 0)
                        else
                            rectfill(0, 0, screen_width, screen_height, 7)
                        end
                    else
                        convo_i += 1
                    end
                end
            },
            { 226, "(ken-lee's face breaks and reveals a motherboard)" },
            { 192, "what the fuck? ken-lee you a robot?" },
            { 226, "sorry, as an ai agent, i cannot fullfill your request." },
            { 192, "man this is fucked up, i killed a person just for a robot?" },
            { 192, "(jeremy notices a tag inside ken-lee's head)" },
            { 196, "agent: ken-lee\nmodel: chad-gpt\ncompany: closedai" },
            { 192, "closedai... i think i know where this company is located. i better check out what the fuck i signed up for..." },
            { 224, "(jeremy destroys the robot for good)" }
        },
        to_end = function()
            return true
        end,
        on_end = function()
            set_notice("find the closedai headquarters to proceed!")
        end
    },
    {
        x = 8 * 23 + 4, y = 6 * 8, sprite = 55, name = "a fortunate aquaintace", missions_needed = { 2 },
        convo = {
            { 196, "(jeremy reads the sign on the building)\n\nclosedai headquarters\nemail: closedai@closed.ai\nif you have any complaint, feel free to shove it up your-" },
            { 196, "(a loud scream interrupts jeremy's reading)" },
            { 228, "open the fucking door you bitches!" },
            { 230, "sir, please leave us alone or i'll call security!" },
            { 228, "fuck you and your security! i am the mighty ken-lao and i'm here to avenge my brother!" },
            { 228, "i have decades of experience in kung-fu! i'll fuck all of you up! or even better, an ak-47 might do the job!" },
            { 192, "ken-lao? this sounds familiar..." },
            { 192, "avenge your brother? is your brother's name by any chance ken-lee?" },
            { 228, "what? yes, yes! how do you know my brother? how could you have seen him when he was dead for 2 years?" },
            { 192, "bro, your brother is a fucking robot! he made me kill someone named slippy who's the leader of the most professional gang in chinatown!" },
            { 228, "those bitches, they turned my brother's body to a robot!" },
            { 192, "what? oh my god, that's horrible! but don't worry, he still wanted to make japantown." },
            { 228, "what japantown are you talking about? stop it with these rumors! we don't want to attack chinatown, it's too useless. also, this slippy guy, is not even a chinese person's name!" },
            { 192, "then who might this slippy be?" },
            { 228, "i don't know, but what i know is that i'm going to kill everybody in this fuckass building!" }
        },
        to_end = function()
            return true
        end,
        on_end = function()
            set_notice("do more investigations to proceed!")
        end
    },
    {
        x = 8 * 2, y = 8 * 2, sprite = 56, name = "sloppy", missions_needed = { 3, 7 },
        convo = {
            { 198, "hey..." },
            { 192, "yo? what are you doing near my house? and what's up with your face? why the fuck is the whole city filled with robots now?" },
            { 198, "it's a long story... why do you care?" },
            { 192, "*mumbles* well i bet it's related to closedai..." },
            { 198, "wait, what did you say? closedai? what do you know about it?" },
            { 192, "well i know for sure that they're some fucked up company, but i still don't know much about them... all i know is that they turned a poor japanese uncle to a robot, but i don't know why..." },
            { 198, "they did the same with me..." },
            { 192, "really? why?" },
            { 198, "let me tell you... closedai is a company that like many others specializes in making artificial intelligence..." },
            { 198, "many people lost their jobs because of ai, but closedai is still greedy. so they decided to make humanoid robots to steal more jobs that require human physicality and to infilitrate them to collect more data..." },
            { 198, "i was one of the victims that lost their job to ai... one day they came up to me and offered a huge sum of money to give up my body once i died..." },
            { 192, "what? why you? and why give money to a dead person?" },
            { 198, "well... my salary is the only thing that was feeding my family... the money was too much to turn down. plus... they knew i had a terminal sickness and didn't have much time left..." },
            { 198, "i died of terminal sickness 5 years ago. i was their first volunteer for this project, but midway through the project they ditched me, like this, incomplete." },
            { 192, "and why is that? and how are you alive now?" },
            { 198, "mid-procedure, they noticed that unlike what they wanted, i got my own conciousness back. i wasn't controllable like the robots they want." },
            { 198, "my real name is donatello, but they named me sloppy because, i was a sloppy project. they started working on me 1 hour after i died, if they were any more late, i would've lost all of my memories" },
            { 198, "this is not being alive, this is being tortured, i wanted to die in peace, not like this..." },
            { 198, "but the good thing is my brain is still connected to their servers, they don't know it... i'm waiting for the perfect opportunity to crack their security and control their new robots to destroy their image, and company..." },
            { 198, "don't worry jeremy..." },
            { 192, "what? how do you know my name?" },
            { 198, "i was connected to ken-lee, i saw you kill my brother slippy, he was also a failed experiment of closedai but at least his body was complete. they tricked you to kill them because they knew he was alive, but they don't know that i am alive too..." },
            { 192, "i'm so fucking sorry, bro. listen, ken-lao is ken-lee's brother, we might be able to stop them if we help each other." },
            { 198, "ok... we'll talk later..." },
            { 192, "by the way, if slippy was a robot, why did he bleed when i killed him?" },
            { 198, "i got too lazy programming the game that i don't want to make another sprite for slippy so i just used an npc sprite..." }
        },
        to_end = function()
            return true
        end,
        on_end = function()
            set_notice("look for more leads to proceed!")
        end
    },
    {
        x = 8 * 6, y = 8 * 2, sprite = 57, name = "aunty shakira",
        convo = {
            { face.shakira, "yo jeremy!" },
            { face.jeremy, "wassup auntie?" },
            { face.shakira, "where the hell is your uncle? i'm waiting for these fuckass eggs to show up so i can cook lunch!" },
            { face.jeremy, "i don't know where the hell uncle sonny is, but i'm sure he's somewhere in the city. i will look for him." },
            { face.shakira, "you sure? he's probably at the store at the bottom right of the city. you better hurry your asses up!" },
            { face.jeremy, "wassup with you auntie? calm down!" },
            { face.shakira, "you lucky your atitude reminds me of your late mother, otherwise i would've punched the bitch out of you!" },
            { face.jeremy, "ah, i miss my parents. may they rest in peace. i'll look for sonny." },
            { face.shakira, "ok honey, take care." }
        },
        to_end = function()
            return true
        end,
        on_end = function()
            set_notice("look for uncle sonny!")
        end
    },
    {
        x = 8 * 24, y = 8 * 27, sprite = 58, name = "uncle sonny", missions_needed = { 5 },
        convo = {
            { face.jeremy, "hey uncle sonny! come on let's go home, shakira is waiting for us!" },
            { face.sonny, "not now jeremy... there's something i need to do first, it is a need..." },
            { face.jeremy, "aw hell nah, i bet you're gonna go kill someone right? please don't get back to your old ways uncle sonny!" },
            { face.sonny, "listen jeremy, you're like my son now. ever since your parents died and we took you, i've grown a great sense of responsibility for you. and now here you are, understanding me when i want to kill someone or not, like a true son." },
            { face.jeremy, "thanks uncle sonny, i appreciate that. but please don't kill anyone..." },
            { face.sonny, "my dear son, let me explain at least. you know that with great power-" },
            { face.jeremy, "comes great responsibility?" },
            { face.sonny, "no jeremy. with great power come great haters. i just posted a story on instameter, i got 200 views, but i only got 199 likes." },
            { face.jeremy, "so? please don't tell me what i'm fearing..." },
            { face.sonny, "i'm sorry son, but it has to be done. this bitchass hater declared war. he'll get what he fucking deserves... but don't worry, i'm not gonna kill him." },
            { face.jeremy, "thank god-" },
            { face.sonny, "you are." },
            { face.jeremy, "ah fuck!" },
            { face.sonny, "i'm not getting those eggs home until you kill him!" },
            { face.sonny, "what do you prefer, jeremy? killing someone or getting your aunt mad? you know that she'll kill us both." },
            { face.jeremy, "alright, jeez. how does he look?" },
            { face.sonny, "he's wearing a white shirt, dark skin, has blue eyes and red hair for some fucking reason. how the fuck is a red-haired person allowed to hate on me?" }
        },
        on_start = function()
            set_notice("find the hater, and bring justice to sonny! +120●")
            set_tip(1)
            player.ammo += 120
            spawn_npc("hater", { 8, 4, 12, 7 }, true)
        end,
        to_end = function()
            for i = 1, #npcs do
                if npcs[i].name == "hater" and npcs[i].health <= 0 then
                    return true
                end
            end
            return false
        end,
        on_end = function()
            set_notice("mission complete!")
        end
    },
    {
        x = 8 * 1, y = 8 * 1, sprite = 58, name = "who's boss", missions_needed = { 6 },
        convo = {
            { face.jeremy, "shit was done uncle sonny." },
            { face.sonny, "well done, son. These haters think they're just-" },
            { nil, nil, function() rectfill(0, 0, screen_width, screen_height, 12) print("invincible", screen_width / 2 - 4 * 5, screen_height / 2 - 2, 10) end },
            { face.jeremy, "alright unc, call me when you need me." },
            { face.sonny, "ok son, here's a 100 bucks. go get something nice for yourself." },
            { face.jeremy, "yoo thanks a lot uncle." }
        },
        to_end = function()
            return true
        end,
        on_end = function()
            set_notice("+100$")
            player.money += 100
        end
    }
}

npcs = {}

projectiles = {}
particles = {}
items = {}

player = {
    x = 0,
    y = 0,
    sizex = 8,
    sizey = 8,
    angle = 0,
    dir = 0, -- clock wise 0-7 (0 = up)
    speed = 0,
    health = 100,
    ammo = 60,
    money = 500
}

player_directions = { 0x07, 0x08, 0x18, 0x28, 0x27, 0x26, 0x16, 0x06, 0x17 }

npc_palette = { { 4, { 4, 5, 6 } }, { 15, { 15, 4 } }, { 11, { 1, 11, 4, 5, 12 } }, { 9, { 1, 2, 5, 6, 7, 8, 9, 10, 12, 13, 14 } } }

-->8
function mapget(x, y)
    if x < 0 or x >= map_width or y < 0 or y >= map_height then
        return 0
    else
        return mget(x, y)
    end
end

function issolid(x, y)
    if x < 0 or x >= map_width or y < 0 or y >= map_height then
        return true
    end
    return fget(mapget(x, y), 7)
end

function solid_at(px, py)
    return issolid(flr(px / tile_size), flr(py / tile_size))
end

function rectsolid(x, y, w, h)
    return solid_at(x, y)
            or solid_at(x + w - 1, y)
            or solid_at(x, y + h - 1)
            or solid_at(x + w - 1, y + h - 1)
end

function checknpc(x, y)
    for i = 1, #npcs do
        if x >= npcs[i].x and x < npcs[i].x + 8 and y >= npcs[i].y and y < npcs[i].y + 8 and npcs[i].health > 0 then
            return i
        end
    end
    return nil
end

function isinrange(x, y, r)
    r = r or 1
    local range = r * 8
    local dx = player.x + 4 - x
    local dy = player.y + 4 - y
    if abs(dx) > range or abs(dy) > range then
        return false
    end
    return dx * dx + dy * dy < range * range
end

function round(n)
    return flr(n + 0.5)
end

function rand(n)
    return flr(rnd(n))
end

function printw(text, x, y, color, limit)
    limit = limit or screen_width
    local cur_x = x
    local cur_y = y

    for i = 1, #text do
        local char = sub(text, i, i)

        local word_too_long = false
        local word = ""
        for j = i, #text do
            local char2 = sub(text, j, j)
            if char2 == " " then
                break
            end
            word = word .. char2
            if #word * 4 > limit - x then
                word_too_long = false -- just split the word
                break
            elseif #word * 4 > limit - cur_x then
                word_too_long = true
                break
            end
        end

        if cur_x + 4 > limit or char == "\n" or word_too_long then
            cur_x = x
            cur_y += 6
        end

        cur_x = print(char, cur_x, cur_y, color)
    end
end

function set_notice(text, length)
    length = length or 3
    notice = text
    noticetime = time() + length
end

function set_tip(text, length)
    length = length or 5
    tip = text
    tiptime = time() + length
end

function setalert(text)
    alert = text
    alert_time = time()
end

function save_game()
    setalert("not implemented yet")
end

function load_game()
    setalert("not implemented yet")
end
-->8
function draw_title()
    --print(time(), 0, screen_height - 6, 7)
    local sequences = {
        {
            timestamp = 0,
            draw = function(diff)
                print("gat 8", screen_width / 2 - 2.5 * 4, 0 + diff * 8, 10)
                print("gat 8", screen_width / 2 - 2.5 * 4 + 1, 1 + diff * 8, 9)
            end
        },
        {
            timestamp = 6.5,
            draw = function(diff)
                print("made by", screen_width - diff * 16, screen_height / 2 - 2 * 6, 7)
                print("azizbgboss", diff * 16 - 10 * 4, screen_height / 2 + 2 * 6, 7)
            end
        },
        {
            timestamp = 12.8,
            draw = function(diff)
                printw("jeremy:\njeff jeffrey the jefferson", screen_width - 4 - diff * 16, 0, 7)
                spr(192, -16 + diff * 16, screen_height * 0.66, 2, 2)
            end
        },
        {
            timestamp = 19,
            draw = function(diff)
                printw("ken-lee:\nlee-ken", 0, -32 + diff * 32, 7)
                spr(194, 0, -16 + diff * 32, 2, 2)

                printw("ken-lao:\nlao-ken", screen_width / 2, screen_height - diff * 32, 7)
                spr(228, screen_width / 2, screen_height + 16 - diff * 32, 2, 2)
            end
        },
        {
            timestamp = 24.5,
            draw = function(diff)
                printw("sloppy:\nzoliathan goliathan the beast", 0, 0 + diff * 16, 7, screen_width / 2)
                spr(198, screen_width / 2 + 16, screen_height - 16 - diff * 16, 2, 2)
            end
        },
        {
            timestamp = 32,
            draw = function(diff)
                print("gat 8", 0, 0, 10)
                print("gat 8", 1, 1, 9)
                print("made by azizbgboss", 0, 8, 7)
                printw("github.com/azizbgboss/gat8", 0, 16, 7)
                printw("version " .. version, 0, 64, 7)
                print("press ❎ to start", 0, 120, 7)
            end
        }
    }
    for i = #sequences, 1, -1 do
        if time() > sequences[i].timestamp then
            local diff = time() - sequences[i].timestamp
            sequences[i].draw(diff)
            break
        end
    end
end

function draw_alert()
    if alert then
        --extra safety
        printw(alert, 0, 0, 7, screen_width)
        if time() - alert_time > 1 then
            print("❎", screen_width - 7, screen_height - 5, 7)
        end
    end
end

function draw_menu()
    print("❎: select, 🅾️: exit", 0, 0, 7)
    for i = 1, #menus[active_menu] do
        local m = menus[active_menu][i]
        if m.title then
            print(((i == menu_choice) and "> " or "  ") .. m.title, 0, i * 6 + 8, 7)
        elseif m.get_title then
            print(((i == menu_choice) and "> " or "  ") .. m.get_title(), 0, i * 6 + 8, 7)
        end
    end
    if menus[active_menu][menu_choice].desc then
        rect(0, screen_height - 4 * 6 - 2, screen_width - 1, screen_height, 1)
        printw(menus[active_menu][menu_choice].desc, 2, screen_height - 4 * 6, 7, screen_width - 2)
    elseif menus[active_menu][menu_choice].get_desc then
        rect(0, screen_height - 4 * 6 - 2, screen_width - 1, screen_height, 1)
        printw(menus[active_menu][menu_choice].get_desc(), 2, screen_height - 4 * 6, 7, screen_width - 2)
    end
end

function check_missions()
    if active_mission then
        if missions[active_mission].update then
            missions[active_mission].update()
        end
        if missions[active_mission].updateOverride then
            updateOverride = missions[active_mission].updateOverride
        end
        if missions[active_mission].to_end() or missions[active_mission].complete then
            missions[active_mission].complete = true
            if missions[active_mission].on_end then
                missions[active_mission].on_end()
                sfx(3)
            end
            active_mission = nil
            mission_id = nil
        end
    end
end

function draw_map()
    for y = 0, screen_height / tile_size do
        for x = 0, screen_width / tile_size do
            local tx, ty = x + flr(scrollx / tile_size), y + flr(scrolly / tile_size)
            draw_tile(mapget(tx, ty), tx * tile_size - scrollx, ty * tile_size - scrolly)
        end
    end
end

function draw_tile(id, x, y)
    if x > 127 or y > 127 or x < -7 or y < -7 then
        return
    end
    spr(id, x, y)
end

function draw_player()
    spr(player_directions[player.dir + 1], player.x - scrollx, player.y - scrolly)
end

function mission_valid(i)
    local m = missions[i]
    if m.complete then
        return false
    end
    if m.missions_needed then
        for j = 1, #m.missions_needed do
            if not missions[m.missions_needed[j]].complete then
                return false
            end
        end
    end
    return true
end

function get_mission_in_range()
    if active_mission then
        return nil
    end
    for i = 1, #missions do
        local m = missions[i]
        if mission_valid(i) and isinrange(m.x + 4, m.y + 4, 2) then
            return i
        end
    end
    return nil
end

function update_mission_id()
    mission_id = get_mission_in_range()
end

function draw_missions()
    for i = 1, #missions do
        local m = missions[i]
        if not active_mission and mission_valid(i) then
            spr(m.sprite, m.x - scrollx, m.y - scrolly)
        end
    end
end

function drop_item(x, y, sprite, on_pickup)
    add(items, { x = x, y = y, sprite = sprite, on_pickup = on_pickup })
end

function draw_items()
    for i = #items, 1, -1 do
        local i = items[i]
        spr(i.sprite, i.x - scrollx, i.y - scrolly)
    end
end

function spawn_npc(name, pal, violent, x, y, dir, health, speed)
    while not x or not y do
        local testx, testy = rand(map_width), rand(map_height)
        if is_legal(testx, testy) then
            x, y = testx * tile_size, testy * tile_size
        end
    end
    violent = violent or rand(3) == 1
    pal = pal or { npc_palette[1][2][rand(#npc_palette[1][2]) + 1], npc_palette[2][2][rand(#npc_palette[2][2]) + 1], npc_palette[3][2][rand(#npc_palette[3][2]) + 1], npc_palette[4][2][rand(#npc_palette[4][2]) + 1] }
    dir = dir or rand(8)
    health = health or 20
    speed = speed or 0.3
    add(npcs, { x = x, y = y, sprite = sprite, dir = rand(8), health = health, speed = speed, name = name, pal = pal, violent = violent })
end

function iswet(x, y)
    return fget(mget(x, y), 2)
end

function is_legal(x, y)
    if x < 0 or x >= map_width or y < 0 or y >= map_height then
        return false
    end
    return fget(mget(x, y), 1)
end

function backtrack(visited, target)
    local dir = visited[target.y * map_width + target.x]
    if dir.x == 0 and dir.y == 0 then
        return target.x, target.y
    end
    local curr = target
    local prev = nil
    while true do
        local dir = visited[curr.y * map_width + curr.x]
        if dir.x == 0 and dir.y == 0 then
            return prev.x, prev.y
        end
        prev = curr
        curr = { x = curr.x - dir.x, y = curr.y - dir.y }
    end
end

function get_next_step(start_x, start_y, target_x, target_y)
    local queue = { { x = start_x, y = start_y } }
    local visited = {}
    visited[start_y * map_width + start_x] = { x = 0, y = 0 }
    local q_idx = 1

    while q_idx <= #queue do
        local curr = queue[q_idx]
        q_idx += 1

        if curr.x == target_x and curr.y == target_y then
            return backtrack(visited, curr)
        end

        for d in all({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
            local dx, dy = d[1], d[2]
            local nx, ny = curr.x + dx, curr.y + dy
            if is_legal(nx, ny) and not visited[ny * map_width + nx] then
                visited[ny * map_width + nx] = { x = dx, y = dy }
                add(queue, { x = nx, y = ny })
            end
        end
    end
    return start_x, start_y
end

function move_npcs()
    for i = #npcs, 1, -1 do
        local n = npcs[i]

        if n.health > 0 then
            if n.scared and not n.violent then
                if time() - n.scared > 10 then
                    n.speed = 0.2
                    n.scared = nil
                else
                    if rand(30) == 0 then
                        n.dir = rand(8)
                    end
                    n.speed = 0.7
                    n.target = nil
                end
            else
                if n.target and n.next_step then
                    local error = 1 -- error radius in pixels
                    local tx, ty = n.next_step[1], n.next_step[2]
                    tx = tx * tile_size + 4
                    ty = ty * tile_size + 4
                    if n.x + 4 < tx - error then
                        if n.y + 4 < ty - error then
                            n.dir = 3
                        elseif n.y + 4 > ty + error then
                            n.dir = 1
                        else
                            n.dir = 2
                        end
                    elseif n.x + 4 > tx + error then
                        if n.y + 4 < ty - error then
                            n.dir = 5
                        elseif n.y + 4 > ty + error then
                            n.dir = 7
                        else
                            n.dir = 6
                        end
                    else
                        if n.y + 4 < ty - error then
                            n.dir = 4
                        elseif n.y + 4 > ty + error then
                            n.dir = 0
                        else
                            n.next_step[1], n.next_step[2] = get_next_step(flr((n.x + 4) / tile_size), flr((n.y + 4) / tile_size), n.target[1], n.target[2])
                            if n.next_step[1] == flr((n.x + 4) / tile_size) and n.next_step[2] == flr((n.y + 4) / tile_size) then
                                n.target = nil
                                n.next_step = nil
                            end
                        end
                    end
                else
                    n.target = nil
                    if n.violent then
                        if rand(120) == 1 then
                            if not isinrange(n.x + 4, n.y + 4, 5) then
                                n.target = { player.x \ tile_size, player.y \ tile_size }
                            end
                        end
                    elseif rand(120) == 1 then
                        n.target = { rand(map_width), rand(map_height) }
                        while not is_legal(n.target[1], n.target[2]) do
                            n.target[1], n.target[2] = rand(map_width), rand(map_height)
                        end
                    end
                    n.next_step = nil
                    if n.target then
                        n.next_step = {}
                        n.next_step[1], n.next_step[2] = get_next_step(flr((n.x + 4) / tile_size), flr((n.y + 4) / tile_size), n.target[1], n.target[2])
                    end
                end
            end
            if n.lastshot then
                if time() - n.lastshot < 1 then
                    n.speed = 0.1 -- they got shot so a bit of immobility first
                end
                if time() - n.lastshot < 3 then
                    if rand(5) == 0 then
                        add_particle(n.x + 4, n.y + 4, 8) -- bleed
                    end
                end
            end
            local dx, dy = cos(-n.dir / 8 + 0.25) * n.speed, sin(-n.dir / 8 + 0.25) * n.speed
            if not issolid((n.x + 4 + dx) / tile_size, (n.y + 4 + dy) / tile_size) then
                n.x += dx
                n.y += dy
            end
        else
            if not n.deathtime then
                n.deathtime = time()
                drop_item(n.x + 4, n.y + 4, 15, function() player.money += rand(100) sfx(2) end)
            elseif time() - n.deathtime > 10 then
                deli(npcs, i)
            end
        end
    end
end

function add_particle(x, y, color, velx, vely)
    velx = velx or (rnd(2) - 1)
    vely = vely or (rnd(2) - 1)
    add(particles, { x = x, y = y, color = color, velx = velx, vely = vely, time = time(), slowdown = 0.9 })
end

function move_particles()
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x += p.velx
        p.y += p.vely
        p.velx *= p.slowdown
        p.vely *= p.slowdown
        if p.x < 0 or p.x > map_width * tile_size or p.y < 0 or p.y > map_height * tile_size or issolid(p.x \ tile_size, p.y \ tile_size) then
            deli(particles, i)
        end
        if time() - p.time > 5 then
            deli(particles, i)
        end
    end
end

function draw_particles()
    for i = #particles, 1, -1 do
        local p = particles[i]
        pset(p.x - scrollx, p.y - scrolly, p.color)
    end
end

function draw_npcs()
    for i = #npcs, 1, -1 do
        local n = npcs[i]
        for j = 1, #npc_palette do
            pal(npc_palette[j][1], n.pal[j], 0)
        end
        if n.health <= 0 then
            spr(player_directions[9], n.x - scrollx, n.y - scrolly)
        else
            spr(player_directions[n.dir + 1], n.x - scrollx, n.y - scrolly)
        end
    end
    pal()
end

function show_trail()
    if trail then
        for i = 1, 10 do
            local dx, dy = cos(-player.angle / 8 + 0.25) * i * 5, sin(-player.angle / 8 + 0.25) * i * 5
            pset(player.x + 4 - scrollx + dx, player.y + 4 - scrolly + dy, 8)
        end
    end
end

function spawn_bullet(x, y, angle, speed, damage)
    x = x or (player.x + 4)
    y = y or (player.y + 4)
    angle = angle or player.angle
    speed = speed or 2
    damage = damage or 5
    add(projectiles, { x = x, y = y, angle = angle, speed = speed, damage = damage })
end

function move_projectiles()
    for i = #projectiles, 1, -1 do
        local p = projectiles[i]
        p.x += cos(-p.angle / 8 + 0.25) * p.speed
        p.y += sin(-p.angle / 8 + 0.25) * p.speed
        if issolid(p.x / tile_size, p.y / tile_size) then
            del(projectiles, p)
        elseif checknpc(p.x, p.y) then
            npcs[checknpc(p.x, p.y)].lastshot = time()
            npcs[checknpc(p.x, p.y)].health -= p.damage
            del(projectiles, p)
        end
    end
end

function draw_projectiles()
    for i = 1, #projectiles do
        local p = projectiles[i]
        local dx, dy = cos(-p.angle / 8 + 0.25) * p.speed, sin(-p.angle / 8 + 0.25) * p.speed
        for j = 1, 4 do
            -- trail
            pset(p.x - scrollx - dx * j, p.y - scrolly - dy * j, 6)
        end
        pset(p.x - scrollx, p.y - scrolly, 0)
    end
end

function move_player()
    player.angle %= 8
    player.angle *= 100
    player.angle = round(player.angle) / 100
    player.dir = round(player.angle) % 8
    if player.speed != 0 then
        local dx = cos(-player.angle / 8 + 0.25) * player.speed
        local dy = sin(-player.angle / 8 + 0.25) * player.speed
        local nx = player.x + dx

        if not rectsolid(nx, player.y, player.sizex, player.sizey) then
            player.x = nx
        end

        local ny = player.y + dy

        if not rectsolid(player.x, ny, player.sizex, player.sizey) then
            player.y = ny
        end
    end

    if player.x > screen_width / 2 and player.x < map_width * tile_size - screen_width / 2 then
        scrollx = player.x - screen_width / 2
    elseif player.x < screen_width / 2 then
        scrollx = 0
    else
        scrollx = map_width * tile_size - screen_width
    end

    if player.y > screen_height / 2 and player.y < map_height * tile_size - screen_height / 2 then
        scrolly = player.y - screen_height / 2
    elseif player.y < screen_height / 2 then
        scrolly = 0
    else
        scrolly = map_height * tile_size - screen_height
    end

    for i = #items, 1, -1 do
        if isinrange(items[i].x + 4, items[i].y + 4, 2) then
            local item = items[i]
            item.on_pickup()
            deli(items, i)
        end
    end
end

function show_debug()
    print("angle: " .. player.angle, 0, 0, 7)
    print("x: " .. player.x .. "(" .. flr(player.x / 8) .. "*8)")
    print("y: " .. player.y .. "(" .. flr(player.y / 8) .. "*8)")
    for i = 1, #npcs do
        if npcs[i].target and npcs[i].next_step then
            print("npc" .. i .. "♥" .. npcs[i].health .. "T" .. npcs[i].target[1] .. "," .. npcs[i].target[2] .. "N" .. npcs[i].next_step[1] .. "," .. npcs[i].next_step[2])
        else
            print("npc" .. i .. "♥" .. npcs[i].health)
        end
    end
end

function show_stats()
    rect(1, screen_height - 8, screen_width - 2, screen_height - 2, 7)
    rectfill(2, screen_height - 7, screen_width - 3, screen_height - 3, 0)
    local last_x = print("♥" .. player.health, 1, screen_height - 7, 8)
    last_x = print("$" .. player.money, last_x + 1, screen_height - 7, 11)
    print("●" .. player.ammo, last_x + 1, screen_height - 7, 1)
end

function show_notices()
    button_notice = nil
    if mission_id then
        local sx, sy = missions[mission_id].x - scrollx - #missions[mission_id].name * 2 + 4, missions[mission_id].y - scrolly - 8
        rectfill(sx - 1, sy - 1, sx + #missions[mission_id].name * 4 - 1, sy + 5, 1)
        print(missions[mission_id].name, sx, sy, 7)
        button_notice = { "❎", "interact" }
    end
    if notice then
        local lines = (#notice - 1) \ (screen_width \ 4) + 1
        rect(1, 1, screen_width - 2, lines * 6 + 1, 1)
        rectfill(2, 2, screen_width - 3, lines * 6, 0)
        printw(notice, 2, 2, 7, screen_width - 3)
        if time() - noticetime > 0 then
            notice = nil
        end
    end
    if tip and not tips[tip].shown then
        local lines = (#tips[tip].text - 1) \ (screen_width \ 4) + 1
        rectfill(1, screen_height - 8 - lines * 6 - 1, screen_width - 2, screen_height - 8 - 1, 8)
        printw(tips[tip].text, 2, screen_height - 8 - lines * 6, 7, screen_width - 3)
        if time() - tiptime > 0 then
            tips[tip].shown = true
            tip = nil
        end
    end
    if button_notice then
        local lastx = 67 --lol
        rectfill(0, 0, screen_width, 6, 1)
        if time() % 2 < 1 then
            lastx = print(button_notice[1], 1, 1, 7)
        else
            print(button_notice[1], 1, 1, 6)
            lastx = print(button_notice[1], 1, 0, 7)
        end
        print(button_notice[2], lastx + 4, 1, 7)
    end
end

function draw_convo()
    local t = missions[convo_mission_id].convo[convo_i]
    if t[3] then
        t[3]()
    else
        rectfill(0, 0, screen_width, screen_height, 0)
        printw(t[2], 0, 0, 7, screen_width)
        spr(t[1], screen_width - 16, screen_height - 16, 2, 2)
        print("❎", screen_width - 16 - 8, screen_height - 5, 7)
    end
end

__gfx__
00000000333333333333333333333333333333333333333300000000000000000000000000000000000000000000000000000000000000000000000000000000
000000003333333333333333333333333333333333333333000bf99000bffb00099fb000000000000000000000000000000000000000000000000000bbbb3bbb
00000000333333333333333333333333333333333333333300ff449004ffff400944ff00000000000000000000000000000000000000000000000000bbb333bb
0000000033333333333333333333333333333333333333330bf444409444444904444fb0000000000000000000000000000000000000000000000000bbb33bbb
00000000333333333333b3333333333333333333333333330f44444094444449044444f0000000000000000000000000000000000000000000000000bbbb33bb
000000003333b33333333333333333333333333333333333094444000444444000444490000000000000000000000000000000000000000000000000bbb333bb
000000003333333333333333333333333333333333333333099440000044440000044990000000000000000000000000000000000000000000000000bbbb3bbb
0000000033333333333333333333333333333b333333333300000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333333333333333333333333333333333333333333300099000000448880009900000000000000000000000000000000000000000000000000000000000
33333333333333333333333333333333333333333333333300444400084444880044440000000000000000000000000000000000000000000000000000555500
3333333333333333333333333333333333333333333333330bf4444088ffff8004444fb00000000000000000000000000000000000000000000000000555a550
3333333333333333333333333333333333333333333333330ff44440898ff00004444ff000000000000000000000000000000000000000000000000005555a50
3333b33333333333333333333b333333b333333333333b330ff444408999999004444ff000000000000000000000000000000000000000000000000005555550
3333333333333333333333333333333333333333333333330bf444408889900004444fb000000000000000000000000000000000000000000000000005555550
33333333333333333333333333333333333333333333333300444400099999000044440000000000000000000000000000000000000000000000000000555500
33333333333333333333333333333333333333333333333300099000000009000009900000000000000000000000000000000000000000000000000000000000
33333333333333333333333333333333333333333333333300000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333333333333333333333333333333333333333333309944000004444000004499000000000000000000000000000000000000000000000000000000000
33333333333333333333333333333333333333333333333309444400044444400044449000000000000000000000000000000000000000000000000000000000
3333333333333333333333333333333333333333333333330f44444094444449044444f000000000000000000000000000000000000000000000000000000000
333333333b333333333333333333333333333333333333330bf444409444444904444fb000000000000000000000000000000000000000000000000000000000
3333333333333333333b333333333333333333333333333300ff449004ffff400944ff0000000000000000000000000000000000000000000000000000000000
333333333333333333333333333333333333333333333333000bf99000bffb00099fb00000000000000000000000000000000000000000000000000000000000
33333333333333333333333333333333333333333333333300000000000000000000000000000000000000000000000000000000000000000000000000000000
333333333333333333333333333333333333333333333b330005500000000000000aa00000066000000000000000000000000000000000000000000000000000
3333333333333333333333333b333333333333333333333300655600008ff8000055550000566500004ff4000000000000000000000000000000000000000000
3333333333333333333333333333333333333333333333330666666006f55f600b5555500555555006ffff600000000000000000000000000000000000000000
333333333333333333333333333333333333333333333333c666666cc666566c055555e085555558566666650000000000000000000000000000000000000000
333333333333333333333333333333333b33333333333333c666666cc666566c0eeeeef085555558566666650000000000000000000000000000000000000000
3333333333333b333333333333333333333333333333333306ffff600666666001fffff005444450066666600000000000000000000000000000000000000000
333333333333333333333333333333333333333333333333001ff1000066660000ffff0000144100006666000000000000000000000000000000000000000000
3333333333333333333333333333333333333333333333330000000000000000000aa00000000000000000000000000000000000000000000000000000000000
55555555555555555555555500000000555555555555555550000000000000055077077077077075500000000000000500000000000000000000000000000000
50000000000000000000000000000000000000000000000550000000000000005077077077077075000000000000000000000000000000000000000000000000
50000000000000000000000000000000000000000000000550000007700000005077077077077075000000077000000000000000000000000000000000000000
50000000000000000000000000000000000000000000000550000007700000005077077077077075000000077000000000000000000000000000000000000000
50000000000000000000000000000000000000000000000550000007700000005077077077077075000000077000000000000000000000000000000000000000
50000000000000000000000000000000000000000000000550000000000000005077077077077075000000000000000000000000000000000000000000000000
50000000000000000000000000000000000000000000000550000000000000005077077077077075000000000000000000000000000000000000000000000000
50000007700777000077770000000000007770077000000550000007700777005077077077077075007770077007770000000000000000000000000000000000
50000007700777000077770000000000007770077000000550000007700777005555555577777777007770077007770000000000000000000000000000000000
50000000000000000000000000000000000000000000000550000000000000000000000077777777000000000000000000000000000000000000000000000000
50000000000000000000000000000000000000000000000550000000000000007777777700000000000000000000000000000000000000000000000000000000
50000007700000000000000000000000000000077000000550000007700000007777777777777777000000000000000000000000000000000000000000000000
50000007700000000000000000000000000000077000000550000007700000000000000077777777000000000000000000000000000000000000000000000000
50000007700000000000000000000000000000077000000550000007700000007777777700000000000000000000000000000000000000000000000000000000
50000000000000000000000000000000000000000000000550000000000000007777777777777777000000000000000000000000000000000000000000000000
50000000000000055555555500000000500000000000000550000000000000050000000055555555555555555555555500000000000000000000000000000000
50000000000000057070707070707070500000000000000550000000000000055000000000000005555555555555555500000000000000000000000000000000
50000000000000050707070707070707500000000000000000000000000000050000000000000005000000000000000000000000000000000000000000000000
50000007700000057000000000000070500000077000000000000007700000050000000770000005000000000000000000000000000000000000000000000000
50000007700000050700000000000007500000077000000000000007700000050000000770000005000000000000000000000000000000000000000000000000
50000007700000057000000000000070500000077000000000000007700000050000000770000005000000000000000000000000000000000000000000000000
50000007700000050700000000000007500000000000000000000000000000050000000000000005000000000000000000000000000000000000000000000000
50000000000000057000000000000070500000000000000000000000000000050000000000000005000000000000000000000000000000000000000000000000
50000000000000050700000000000007500000077007770000777007700000050077700770000005007770077007770000000000000000000000000000000000
00000000000000007000000000000070500000077007770000777007700000050077700770000005007770077007770000000000000000000000000000000000
00000000000000000700000000000007500000000000000000000000000000050000000000000005000000000000000000000000000000000000000000000000
00000000000000007000000000000070500000000000000000000000000000050000000000000005000000000000000000000000000000000000000000000000
00000000000000000700000000000007500000000000000000000000000000050000000770000005000000077000000000000000000000000000000000000000
00000000000000007000000000000070500000000000000000000000000000050000000770000005000000077000000000000000000000000000000000000000
00000000000000000700000000000007500000000000000000000000000000050000000770000005000000077000000000000000000000000000000000000000
00000000000000007070707070707070500000000000000000000000000000050000000000000005000000000000000000000000000000000000000000000000
00000000000000000707070707070707555555555555555555555555555555555000000000000005500000000000000500000000000000000000000000000000
333366663333aaaa5999aaaa3333eeeeaaaaaaaaaaaaaaaa33333333333333333333333333333333333333333333333333336666666666666666666666666666
333d66663339aaaa5999aaaa3332eeeeaaaaaaaaaaaaaaaa33333333333333333333333333333333333333333333333333316666666666666666666666666666
33dd66663399aaaa599caaaa3322eeeeaaaaaaaaaaaaaaaa33333333333333333333333333333cccccccccccccc3333333116657575757555555555555555566
3ddc6666399caaaa59ccaaaa322ceeeeaaaaaaaaaaaaaaaa3333344334433443344333333333cccccccccccccccc3333311c6655555555555555555555555566
5dcc666659ccaaaa5cc9aaaa52cceeeeaaaaaaaa9999cc99333344444444444444443333333cccccccccccccccccc33351cc6657575757555555557775777566
5ccd66665cc9aaaa5c99aaaa5cc2eeeeaaaaaaaa999cc99933344433333333333344433333cccccccccccccccccccc335cc16655577755555555557575575566
5cdd66665c99aaaa5999aaaa5c22eeeeaaaaaaaa99cc999933344333333333333334433333cccccccccccccccccccc335c116657575757555555557775575566
5ddd66665999aaaa5999aaaa5222eeeeaaaaaaaa5555555533334333333333333334333333cccccccccccccccccccc3351116655575755555555557575777566
5ddd666666666666599caaaa5222eeeeeeeeeeeeaaaaaaaa33334333333333333334333333cccccccccccccccccccc33511c6657555557555555555555555566
5ddd66666666666659ccaaaa5222eeeeeeeeeeeeaaaaaaaa33344333333333333334433333cccccccccccccccccccc3351cc6655757575555555555555555566
5ddc6666666666665cc9aaaa522ceeeeeeeeeeeeaaaaaaaa333443333333a5333334433333cccccccccccccccccccc335cc16666666666666666666666666666
5dcc6666666666665c99aaaa52cceeeeeeeeeeeeaaaaaaaa333343333333aa333334333333cccccccccccccccccccc335c116666666666666666666666666666
5ccd666666666666599999cc5cc2eeeeeeeeeeee999cc99333334333333533333334333333cccccccccccccccccccc33511111cc111cc111111111cc111cc113
5cdd66666666666659999cc95c22eeeeeeeeeeee99cc993333344333335333333334433333cccccccccccccccccccc3351111cc111cc111144111cc111cc1133
5ddd6666666666665999cc995222eeeeeeeeeeee9cc9933333344333333333333334433333cccccccccccccccccccc335111cc111cc111144111cc111cc11333
5ddd666666666666555555555222eeeeeeeeeeee5555333333334333333333333334333333cccccccccccccccccccc3355555555555555555555555555553333
5ddc66666666666666666666522ceeeeeeeeeeeeeeeeeeee33334333333333333334333333cccccccccccccccccccc3333333333000000000000000000000000
5dcc6666666666666666666652cceeeeeeeeeeeeeeeeeeee33344333333333333334433333cccccccccccccccccccc3333333333000000000000000000000000
5ccd666666666666666666665cc2eeeeeeeeeeeeeeeeeeee33344433333333333344433333ccccccccccccccccccc33333333333000000000000000000000000
5cdd666666666666666666665c22eeeeeeeeeeeeeeeeeeee333344444444444444443333333ccccccccccccccccc333333333333000000000000000000000000
5dddddccddddccdddddccdd3522222cc2222cc22222cc2233333344334433443344333333333ccccccccccccccc3333333333333000000000000000000000000
5ddddccddddccdddddccdd3352222cc2222cc22222cc223333333333333333333333333333333ccccccccccccc33333333333333000000000000000000000000
5dddccddddccdddddccdd3335222cc2222cc22222cc2233333333333333333333333333333333333333333333333333333333333000000000000000000000000
55555555555555555555333355555555555555555555333333333333333333333333333333333333333333333333333333333333000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000033333333333333333333333333333333000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000033333333333333333333333333333333000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000033333333333333333333333333333333000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000033333333333333333333333333333333000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000033333333333333333333333333333333000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000033333333333333333333333333333333000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000033333333333333333333333333333333000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000033333333333333333333333333333333000000000000000000000000
00000444000000000000000000660000000000000000000000000000000000000000055555500000000000000000000000000000000000000000000000000000
00044444440000000000000666660000000000000000000000000000000000000000555545550000000000066600000000000000000000000000000000000000
00044444440000000000666666600000666666666666666600000fffe50000000000444444456600000000666660000000000000000000000000000000000000
000ffffffff00000000066666660000066666666666666660000ffffe55500000000477447746660000000fffff0000000000000000000000000000000000000
000f77ff77f0000000006f66f6f000006dddd6dddddd6dd60000fffe55555000000041744174666000000044f440000000000000000000000000000000000000
000fb7ffb7f000000000ffffffff000066666666666666660000fffe555550000000444444440000000000fffff0000000000000000000000000000000000000
000ffffffff000000000111ff11100006ddddddd6dddd6d60000f77e553350000000444444440000000000fffff0000000000000000000000000000000000000
000fff44fff0000000001f1ff1f1f00066666666666666660000f17e55b35500000048844484000000000ffffff0000000000000000000000000000000000000
000f8f44f8f000000000fffffffff0006ddddddd6dddddd60000fffe55555500000044888884000000000f888ff0000000000000000000000000000000000000
000f88ff88f000000000fffffffff00066666666666666660000fffe55555500000004444448800000000fffff00000000000000000000000000000000000000
0000f8888ff0000000000666666660006ddd6dddd6ddddd60000f8fe555550000008884444888800000557fff755500000000000000000000000000000000000
00099ffff9999999000066f6ff6f660066666666666666660000f88e565550000888888888888880005557000755550000000000000000000000000000000000
09999999999999990cccccf6ff66cccc666666666666611600aaff886565aa008888888888888888055555707555555000000000000000000000000000000000
99999999999999990cccccc6ccc6cccc6666666666666666aaaafffe5555aaaa8888888888888888555555707555555500000000000000000000000000000000
9999999999999999ccccccc66cc66ccc0000000000000000aaaaaaaaaaaaaaaa8888888888888888555555505555555500000000000000000000000000000000
9999999999999999cccccccc6ccc6ccc0000000000000000aaaaaaaaaaaaaaaa8888888888888888555555555555555500000000000000000000000000000000
00000444000000000000000000660000000000050000000000000000111100000000000000000000000000000000000000000000000000000000000000000000
00544444440500000000000666660000000000050000000000000001111111000000000000000000000000000000000000000000000000000000000000000000
0005554445500000000066666660000000000ff5ff0000000000000ff11111100000000000000000000000000000000000000000000000000000000000000000
000ff5f555f000000000665555603000000555fff5550000000000ffff1f11100000000000000000000000000000000000000000000000000000000000000000
000f77ff77f0000000006555533300000000f55f55f00000000000ff4ffff0000000000000000000000000000000000000000000000000000000000000000000
000fb7ffb7f00ff00000f555335f00000000fffffff00000000000fcffff4f000000000000000000000000000000000000000000000000000000000000000000
000ffffffff00fff0000fc55555f000000008fffff80000000ffffffffffff000000000000000000000000000000000000000000000000000000000000000000
000fff44fff00fff0000cc555555f0000000fffffff000000fffffcfffffcff00000000000000000000000000000000000000000000000000000000000000000
000fff44fff009990000c5555555f0000000ff555ff000000ff4fffffffffcf00000000000000000000000000000000000000000000000000000000000000000
000ff88888f009990000c5585885f0000000f55f55f000000ff44ff44fffff000000000000000000000000000000000000000000000000000000000000000000
000088fff88004990000055888556000000005fff550000000ff4444ffffff000000000000000000000000000000000000000000000000000000000000000000
00099ffff99994990000655555555600001155111151111000fffffffffff5000000000000000000000000000000000000000000000000000000000000000000
09999999999994990ccccc555555cccc111151111155111100555578887555500000000000000000000000000000000000000000000000000000000000000000
99999999999994490cccccc6ccc6cccc111551111115111105555577877555550000000000000000000000000000000000000000000000000000000000000000
9999999999999949ccccccc66cc66ccc111511111115111155555557875555550000000000000000000000000000000000000000000000000000000000000000
9999999999999949cccccccc6ccc6ccc111111111111111155555557875555550000000000000000000000000000000000000000000000000000000000000000
__gff__
0002020202020000000000000000000002020202020200000000000000000000020202020202000000000000000000000202020202020000000000000000000001010100010101010303010100000000010101000101010103030101000000000101010101010101010101010000000000000101010101010101010100000000
8080808080808080800606068080808080808080808080008006040680808080808080808080808080060606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0203049783948184606180918091809180918091606104050203606102030405000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
12010383949492956061a0a2a0a2a0a2a0a2a0a2606114150405606112131415000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
220303a3a4a53025464742424242424258424242666730251415484922238184000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3233341415010202565752525252525259525252767730352425606181848484000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
809191919104131348490405020304050203042425308c8d8e8f606182848484000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0a1a1a1a223313360619715121314151213143435309c9d9e9f606192858595000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
424242424242424262634242424242426a6b42584242424242424a4b42424242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
525252525252525272735252525252527a7b52595252525252525a5b52525252000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0203040502030497606180919191919160610414153030050203049786878787000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
121304053030141560619091a1a1a1a2606114242530301512130486a8898a8a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2223141530302425606190919191919160612434353030252223149630999a9a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
32332425303034356061a0a1a1a1a1a260613435323334353233249630999a9a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0203343530300405464742424242424268690530300304050203349630999a9a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1213141504053030565752525252525278791530301314151213149612999a9a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2223242514153030606124252223242560612530302324252223249622a99a9a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
323334352425303060613435323334356061353030333435323334969733a9aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020304050203040560610405020304056061040502030405043030a687878802000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1213141512131415606114151213141560611415121314151415303030309802000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2223242522232425484924252223242548492425222324252425303030309802000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3233343532040530606134353233343560613435323334353435303030303002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0203040502141530606104050203040560613030020304053030303030303002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1213141512242530606114151213141560613030121314153030303030303002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4242424258424242626342424242424262634242424242424242424242424242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5252525259525252727352525252525272735252525252525252525252525252000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0203042425303005606104050203040560610405021415303030242530303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1213143435303015606114151213141560611415122425303030343530303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2223242522232425606124252223242560612425223435303030303030838494000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3233343532333435606134353233343560613435323334353030303030829484000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0203040530300405484904040530300548490404053004053030303004938494000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1213141530301415606114141530301560618384948494849484948494849484000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202242530300202606102242530300260618294849484948494849484948494000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020234353030020260610234353030026061a385a485a485a485a485a485a495000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100002665026650266502665026650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400003605000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000361503a150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000013550135500e5500e55008550085500955009550095500955000000085000050009550000000955000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600002b0202b0202b0202b0251f0201f0201f0201f0251b0201b0201b0201b0251f0201f0201f0201f025200202002020020200251f0201f0201f0201f0251d0201d0201d0201d0251f0201f0201f0201f025
010600001f0201f0201f0201f0251f0201f0201f0201f025180201802018020180251f0201f0201f0201f0251b0201b0201b0201b0251b0201b0201b0201b025170201702017020170251b0201b0201b0201b025
010600001f0201f0201f0201f025130201302013020130251b0201b0201b0201b02513020130201302013025200202002020020200251d0201d0201d0201d0251402014020140201402514020140201402014025
0106000023020230202302023025130201302013020130251f0201f0201f0201f025130201302013020130250e0200e0200e0200e025110201102011020110251d0201d0201d0201d02511020110201102011025
010600001412014120141201412014120141201412014120141201412014120141201412014120141201412518120181201812018120181201812018120181201812018120181201812018120181201812018125
010600000842008420084200842008420084200842008420084200842008420084200842008420084200842502420024200242002420024200242002420024200242002420024200242002420024200242002425
010600001b1201b1201b1201b1201b1201b1201b1201b1201b1201b1201b1201b1201b1201b1201b1201b1251a1201a1201a1201a1201a1201a1201a1201a1201a1201a1201a1201a1201a1201a1201a1201a125
010600000742007420074200742007420074200742007420074200742007420074200742007420074200742501420014200142001420014200142001420014200142001420014200142001420014200142001425
010600001e1201e1201e1201e1201e1201e1201e1201e1201e1201e1201e1201e1201e1201e1201e1201e1251a1201a1201a1201a1201a1201a1201a1201a1201a1201a1201a1201a1201a1201a1201a1201a125
010600000042000420004200042000420004200042000420004200042000420004200042000420004200042505420054200542005420054200542005420054200542005420054200542005420054200542005425
010600001d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d12517120171201712017120171201712017120171201712017120171201712017120171201712017125
010600000242002420024200242002420024200242002420024200242002420024200242002420024200242002420024200242002420024200242002420024200242002420024200242002420024200242002425
0106000018220182250000000000132201322500000000001a2201a2250000000000132201322500000000001b2201b2250000000000132201322500000000001a2201a225000000000013220132250000000000
010600000042000420004200042500420004200042000425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0106000018220182250000000000132201322500000000001a2201a22500000000001322013225000000000018220182250000000000132201322500000000001722017225000000000013220132250000000000
010600000c4200c4200c4200c4250c4200c4200c4200c425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007420074200742007425
010600001822018225000000000013220132250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600000c4200c4200c4200c4250c4200c4200c4200c425000000000000000000000000000000000000000005420054250542005425074200742507420074250842008425084200842507420074250742007425
010600001822018225000000000013220132250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0106000018120181201812018125131201312013120131251a1201a1201a1201a125131201312013120131251b1201b1201b1201b125131201312013120131251a1201a1201a1201a12513120131201312013125
010600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000183251832518325183252432500000000000000000000000000000000000
0106000018120181201812018125131201312013120131251a1201a1201a1201a1251312013120131201312518120181201812018125131201312013120131251712017120171201712513120131201312013125
0106000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001a3251a3251a325000002632026325000000000000000000000000000000
0106000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001b3251b3251b325000002732027325000000000000000000000000000000
0106000018120181201812018125131201312013120131251a1201a1201a1201a1250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600000000000000000000000000000000000000000000000000000000000000001a3251a3251a3250000026320263250000000000243252432524325000001832018325000000000023320233202332023325
010600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000183251832518325183252432500000000000000000000000000000000000
010600000c4200c4200c4200c4250c4200c4200c4200c425000000000000000000000000000000000000000011420114251142011425134201342513420134251442014425144201442513420134251342013425
010600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000021520215250000000000
010600002422024220242202422024220242202422024225262202622026220262252722027225000000000000000000000000000000292202922029220292202922029225000000000000000000000000000000
010600000f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f1200f125
010600002b2202b2250000000000132201322500000000001a2201a2250000000000132201322500000000001b2201b2250000000000132201322500000000001a2201a225000000000013220132250000000000
010600001832018320183201832018320183201832018320183201832018320183201832018320183201832500000000000000000000000000000000000000000000000000000000000000000000000000000000
010600000512005120051200512005120051200512005120051200512005120051200512005120051200512005120051200512005120051200512005120051200512005120051200512005120051200512005125
0106000027220272250000000000132201322500000000001a2201a22500000000001322013225000000000026220262250000000000132201322500000000001722017225000000000013220132250000000000
010600001a3201a3201a3201a3201a3201a3201a3201a3201a3201a3201a3201a3201a3201a3201a3201a32500000000000000000000000000000000000000000000000000000000000000000000000000000000
010600001412014120141201412014120141201412014120141201412014120141201412014120141201412014120141201412014120141201412014120141201412014120141201412014120141201412014125
0106000024220242250000000000132201322500000000001a2201a2250000000000132201322500000000001b2201b2250000000000132201322500000000001a2201a225000000000013220132250000000000
010600001d3201d3201d3201d3201d3201d3201d3201d3201d3201d3201d3201d3201d3201d3201d3201d32500000000000000000000000000000000000000000000000000000000000000000000000000000000
010600001312013120131201312013120131201312013120131201312013120131201312013120131201312500000000000000000000000000000000000000000000000000000000000000000000000000000000
010600001f2201f22500000000001322013225000000000000000000000000000000000000000000000000001b2201b2201b2201b2201b2201b2201b2201b2201b2201b2201b2201b2201b2201b2201b2201b225
010600001b3201b3201b3201b3201b3201b3201b3201b3201b3201b3201b3201b3201b3201b3201b3201b32500000000000000000000000000000000000000000000000000000000000000000000000000000000
010600001a2201a2250000000000132201322500000000001a2201a2250000000000132201322500000000001b2201b2250000000000132201322500000000001a2201a225000000000013220132250000000000
010600001832018320183201832018320183201832018320183201832018320183201832018320183201832526320263202632026320263202632026320263253032030320303203032030320303203032030325
0106000018220182250000000000132201322500000000001a2201a22500000000001322013225000000000026220262250000000000132201322500000000001722017225000000000013220132250000000000
010600001a3201a3201a3201a3201a3201a3201a3201a3201a3201a3201a3201a3201a3201a3201a3201a3252c3202c3202c3202c3252c3202c3202c3202c3252c3202c3202c3202c3252c3202c3202c3202c325
0106000027220272250000000000132201322500000000001a2201a2250000000000132201322500000000002b2202b2250000000000132201322500000000001a2201a225000000000013220132250000000000
010600001d3201d3201d3201d3201d3201d3201d3201d3201d3201d3201d3201d3201d3201d3201d3201d32530320303203032030320303203032030320303250000000000000000000000000000000000000000
010600001312013120131201312013120131201312013120131201312013120131201312013120131201312503120031200312003120031200312003120031200312003120031200312003120031200312003125
010600002c2202c225000000000013220132250000000000000000000000000000000000000000000000000030220302203022030220302203022030220302203022030220302203022030220302203022030225
010600001b3201b3201b3201b3201b3201b3201b3201b3201b3201b3201b3201b3201b3201b3201b3201b32532320323203232032320323203232032320323252732027320273202732027320273202732027325
0106000033220332250000000000132201322500000000001a2201a22500000000001322013225000000000026220262250000000000132201322500000000001722017225000000000013220132250000000000
010600001f2201f225000000000013220132250000000000000000000000000000000000000000000000000027220272202722027220272202722027220272202722027220272202722027220272202722027225
0106000018220182250000000000132201322500000000001a2201a2250000000000132201322500000000001a2201a2250000000000132201322500000000001722017225000000000013220132250000000000
010600001b2201b2250000000000132201322500000000001a2201a2250000000000132201322500000000002b2202b2250000000000132201322500000000001a2201a225000000000013220132250000000000
010600002022020225000000000013220132250000000000000000000000000000000000000000000000000024220242202422024220242202422024220242202422024220242202422024220242202422024220
__music__
00 08424344
00 09424344
00 0a424344
00 0b424344
00 0c0d4344
00 0e0f4344
00 10114344
00 12134344
00 14154344
00 16174344
00 14154344
00 18194344
00 14154344
00 16174344
00 14154344
00 1a194344
00 1b1c1544
00 1d1e1744
00 1b1f1544
00 20211944
00 1b221544
00 1d1e1744
00 1b1f1544
00 20212324
00 1b221544
00 1d1e1744
00 1b1f1544
00 20211944
00 1b221544
00 1d1e1744
00 1b1f1544
00 20212344
00 1b141544
00 1d161744
00 1b141544
00 20181944
00 1b141544
00 1d161744
00 1b141544
00 20252344
00 26272815
00 292a2b17
00 2c2d2e15
00 2f303119
00 26323315
00 29343517
00 2c363715
00 38393a23
00 26142815
00 293b2b17
00 2c2d2e15
00 2f3c3119
00 26323315
00 293d3517
00 2c3e3715
00 383f3a23

