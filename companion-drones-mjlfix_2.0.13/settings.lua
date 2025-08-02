data:extend({
    {
        type = "bool-setting",
        name = "set_hard_mode",
        setting_type = "startup",
        default_value = false,
        order = "a",
        localised_description = "Makes the companion start out bad then get better over time. Also makes the recipes mid-late game tier--take good care of your one and only companion for now! See the mod description for more details."
    },
	{
		type = "bool-setting",
		name = "companion-voice-lines",
		setting_type = "startup",
		default_value = true,
		order = "c",
        localised_description = "Do you want your companion to say little quips as it does stuff?"
	},
    {
        type = "int-setting",
        name = "set_update_interval",
        setting_type = "startup",
        default_value = 5,
        minimum_value = 1,
        maximum_value = 1200,
        order = "b",
        localised_description = "How many ticks do companions wait before checking for new jobs? Lower = more responsive, higher = more performant. Note: setting this very low AND having many companions will probably tank your UPS. Recommend adding at least 2 for each companion you plan to have running simultaneously (i.e. two companions = 7, three = 9, etc). Default: 5"
    },
	{
		type = "int-setting",
		name = "companion-idle-chatter-delay",
		setting_type = "runtime-per-user",
		default_value = 600,
		minimum_value = 5,
		maximum_value = 3141592653589,
		order = "a",
		localised_description = "Roughly how many seconds on average should Companion wait before speaking an idle phrase? Minimum: 5 seconds, default: 600 (ten minutes)."
	},
	{
		type = "bool-setting",
		name = "set-fuel-preference",
		setting_type = "runtime-per-user",
		default_value = true,
		localised_description = "Check the box if you want the companion to use your best fuels first (Uranium, rocket, jet, etc). Uncheck if you want the companion to use your worst fuels first (spoilage, wood, coal, etc)"
	},
})