data:extend({
    {
        type = "bool-setting",
        name = "set-challenge-mode",
        setting_type = "startup",
        default_value = false,
        order = "c",
        localised_description = {"settings.set-challenge-mode"}
    },
	{
		type = "bool-setting",
		name = "companion-voice-lines",
		setting_type = "startup",
		default_value = true,
		order = "b",
        localised_description = {"settings.companion-voice-lines"}
	},
    {
        type = "int-setting",
        name = "set-update-interval",
        setting_type = "startup",
        default_value = 5,
        minimum_value = 1,
        maximum_value = 1200,
        order = "d",
        localised_description = {"settings.set-update-interval"}
    },
	{
		type = "int-setting",
		name = "companion-idle-chatter-delay",
		setting_type = "runtime-per-user",
		default_value = 600,
		minimum_value = 5,
		maximum_value = 3141592653589,
		order = "a",
		localised_description = {"settings.companion-idle-chatter-delay"}
	},
	{
		type = "bool-setting",
		name = "set-fuel-preference",
		setting_type = "runtime-per-user",
		default_value = false,
		localised_description = {"settings.set-fuel-preference"}
	},
    {
        type = "int-setting",
        name = "set-mode",
        setting_type = "startup",
		default_value = 0,
		minimum_value = 0,
		maximum_value = 3,
		order = "a",
        localised_description = {"settings.set-mode"}
    },
})