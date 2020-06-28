/mob/proc/format_emote(var/emoter = null, var/message = null)
	var/pretext
	var/subtext
	var/nametext
	var/end_char
	var/start_char
	var/name_anchor
	var/anchor_char = get_prefix_key(/decl/prefix/visible_emote)

	if(!message || !emoter)
		return

	message = html_decode(message)

	name_anchor = findtext(message, anchor_char)
	if(name_anchor > 0) // User supplied emote with visible_emote token (default ^)
		pretext = copytext(message, 1, name_anchor)
		subtext = copytext(message, name_anchor + 1, length(message) + 1)
	else
		// No token. Just the emote as usual.
		subtext = message

	// did the user attempt to use more than one token?
	if(findtext(subtext, anchor_char))
		// abort abort!
		to_chat(emoter, "<span class='warning'>You may use only one \"[anchor_char]\" symbol in your emote.</span>")
		return

	if(pretext)
		// Add a space at the end if we didn't already supply one.
		end_char = copytext(pretext, length(pretext), length(pretext) + 1)
		if(end_char != " ")
			pretext += " "

	// Grab the last character of the emote message.
	end_char = copytext(subtext, length(subtext), length(subtext) + 1)
	if(!(end_char in list(".", "?", "!", "\"", "-", "~")))
		// No punctuation supplied. Tack a period on the end.
		subtext += "."

	// Add a space to the subtext, unless it begins with an apostrophe or comma.
	if(subtext != ".")
		// First, let's get rid of any existing space, to account for sloppy emoters ("X, ^ , Y")
		subtext = trim_left(subtext)
		start_char = copytext(subtext, 1, 2)
		if(start_char != "," && start_char != "'")
			subtext = " " + subtext

	pretext = capitalize(html_encode(pretext))
	nametext = html_encode(nametext)
	subtext = html_encode(subtext)
	// Store the player's name in a nice bold, naturalement
	nametext = "<B>[emoter]</B>"
	return pretext + nametext + subtext

// All mobs should have custom emote, really..
//m_type == 1 --> visual.
//m_type == 2 --> audible
/mob/proc/custom_emote(var/m_type=1,var/message = null, var/log_emote = 1)
	if(usr && stat || !use_me && usr == src)
		to_chat(src, "You are unable to emote.")
		return

	var/muzzled = istype(src.wear_mask, /obj/item/clothing/mask/muzzle)
	if(m_type == 2 && muzzled) return

	var/input
	if(!message)
		input = sanitize(input(src,"Choose an emote to display.") as text|null)
	else
		input = message
	if(input)
		message = format_emote(src, message)
	else
		return


	if (message)
		send_emote(message, m_type)
		if (log_emote)
			log_emote("[name]/[key] : [message]",ckey=key_name(key))

/mob/proc/emote_dead(var/message)

	if(client.prefs.muted & MUTE_DEADCHAT)
		to_chat(src, "<span class='danger'>You cannot send deadchat emotes (muted).</span>")
		return

	if(!(client.prefs.toggles & CHAT_DEAD))
		to_chat(src, "<span class='danger'>You have deadchat muted.</span>")
		return

	if(!src.client.holder)
		if(!config.dsay_allowed)
			to_chat(src, "<span class='danger'>Deadchat is globally muted.</span>")
			return


	var/input
	if(!message)
		input = sanitize(input(src, "Choose an emote to display.") as text|null)
	else
		input = message

	if(input)
		log_emote("Ghost/[src.key] : [input]",ckey=key_name(src))
		say_dead_direct(input, src)


//This is a central proc that all emotes are run through. This handles sending the messages to living mobs
/mob/proc/send_emote(var/message, var/type)
	var/list/messageturfs = list()//List of turfs we broadcast to.
	var/list/messagemobs = list() 
	var/list/ghosts = list()
	var/list/ghosts_nearby = list()

	var/hearing_aid = FALSE
	if(type == 2 && ishuman(src))
		var/mob/living/carbon/human/H = src
		hearing_aid = H.has_hearing_aid()

	for (var/turf in view(world.view, get_turf(src)))
		messageturfs += turf

	for(var/mob/M in player_list)
		if (!M.client || isnewplayer(M))
			continue
		if(get_turf(M) in messageturfs)
			if (isobserver(M))
				ghosts_nearby += M
				continue
			else if (isliving(M) && !(type == 2 && ((sdisabilities & DEAF) && !hearing_aid) || ear_deaf > 1))
				messagemobs += M
		else if(src.client)
			if (M.stat == DEAD && (M.client.prefs.toggles & CHAT_GHOSTSIGHT))
				ghosts += M
				continue

	for (var/mob/N in messagemobs)
		N.show_message(message, type)

	for(var/mob/O in ghosts)
		O.show_message("[ghost_follow_link(src, O)] [message]", type)
	
	for(var/mob/GN in ghosts_nearby)
		GN.show_message("[ghost_follow_link(src, GN)] <b>[message]</b>", type)
