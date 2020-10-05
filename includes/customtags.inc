#pragma semicolon 1
#pragma newdecls required

// COPYRIGHT PSYCHONIC
// USED WITH PERMISSION
#if defined _customtags_included
    #endinput
#endif
#define _customtags_included

#define CUSTOM_TAGS_VERSION 4

#define TAG_SIZE 64
#define SV_TAGS_SIZE 256

static ConVar sv_tags;
static ArrayList custom_tags;

static bool are_tags_hooked = false;
static bool ignore_next_change = false;

stock void AddCustomServerTag(const char[] tag)
{
    if (sv_tags == INVALID_HANDLE)
        sv_tags = FindConVar("sv_tags");

    if (custom_tags == INVALID_HANDLE)
        custom_tags = new ArrayList(TAG_SIZE);

    if (custom_tags.FindString(tag) == -1)
        custom_tags.PushString(tag);

    char current_tags[SV_TAGS_SIZE];
    sv_tags.GetString(current_tags, sizeof(current_tags));
    // already have this tag
    if (StrContains(current_tags, tag) > -1) return;

    char new_tags[SV_TAGS_SIZE];
    Format(new_tags, sizeof(new_tags), "%s%s%s", current_tags, current_tags[0] != 0 ? "," : "", tag);

    int flags = sv_tags.Flags;
    sv_tags.Flags = flags & ~FCVAR_NOTIFY ;
    ignore_next_change = true;
    sv_tags.SetString(new_tags);
    ignore_next_change = false;
    sv_tags.Flags = flags;

    if (!are_tags_hooked)
    {
        sv_tags.AddChangeHook(OnTagsChanged);
        are_tags_hooked = true;
    }
}

stock void RemoveCustomServerTag(const char[] tag)
{
    if (sv_tags == INVALID_HANDLE)
        sv_tags = FindConVar("sv_tags");

    // we wouldn't have to check this if people aren't removing before adding, but... you know...
    if (custom_tags != INVALID_HANDLE)
    {
        int idx = custom_tags.FindString(tag);
        if (idx > -1)
        {
            custom_tags.Erase(idx);
        }
    }

    char current_tags[SV_TAGS_SIZE];
    sv_tags.GetString(current_tags, sizeof(current_tags));
    // tag isn't on here, just bug out
    if (StrContains(current_tags, tag) == -1) return;

    ReplaceString(current_tags, sizeof(current_tags), tag, "");
    ReplaceString(current_tags, sizeof(current_tags), ",,", "");

    int flags = sv_tags.Flags;
    sv_tags.Flags = flags & ~FCVAR_NOTIFY;
    ignore_next_change = true;
    sv_tags.SetString(current_tags);
    ignore_next_change = false;
    sv_tags.Flags = flags;
}

public void OnTagsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    // we fired this callback, no need to reapply tags
    if (ignore_next_change) return;

    // reapply each custom tag
    for (int i = 0; i < custom_tags.Length; i++)
    {
        char tag[TAG_SIZE];
        custom_tags.GetString(i, tag, sizeof(tag));
        AddCustomServerTag(tag);
    }
}
