---@meta rime

--- 全局对象

---@class RimeAPI
---@field get_rime_version fun(): string
---@field get_shared_data_dir fun(): string
---@field get_user_data_dir fun(): string
---@field get_sync_dir fun(): string
---@field get_distribution_name fun(): string
---@field get_distribution_code_name fun(): string
---@field get_distribution_version fun(): string
---@field get_user_id fun(): string
---@field get_time_ms fun(): integer
---@field regex_match fun(input: string, pattern: string): boolean
---@field regex_search fun(input: string, pattern: string): string[] | nil
---@field regex_replace fun(input: string, pattern: string, fmt: string): string
rime_api = {}

---@class Log
---@field info fun(s: string)
---@field warning fun(s: string)
---@field error fun(s: string)
log = {}

--- 在 lua_translator 或 Translation 的生成函数里产出一个候选
---@param cand Candidate
function yield(cand) end

--- 常量（librime-lua 只以字符串或整数传递，不导出全局表）

---@alias ConfigType "kNull"|"kScalar"|"kList"|"kMap"

---@alias SegmentType "kVoid"|"kGuess"|"kSelected"|"kConfirmed"

--- 0 为 kRejected，1 为 kAccepted，2 为 kNoop
---@alias ProcessResult 0|1|2

--- 对象接口及构造函数

---@class Env
---@field engine Engine
---@field name_space string

---@class Engine
---@field schema Schema
---@field context Context
---@field active_engine Engine
---@field process_key fun(self: self, key_event: KeyEvent): boolean
---@field compose fun(self: self, ctx: Context)
---@field commit_text fun(self: self, text: string)
---@field apply_schema fun(self: self, schema: Schema)

---@class Context
---@field composition Composition
---@field commit_history CommitHistory
---@field input string
---@field caret_pos integer
---@field commit_notifier Notifier
---@field select_notifier Notifier
---@field update_notifier Notifier
---@field delete_notifier Notifier
---@field option_update_notifier OptionUpdateNotifier
---@field property_update_notifier PropertyUpdateNotifier
---@field unhandled_key_notifier KeyEventNotifier
---@field commit fun(self: self)
---@field get_commit_text fun(self: self): string
---@field get_script_text fun(self: self): string
---@field get_preedit fun(self: self): Preedit
---@field is_composing fun(self: self): boolean
---@field has_menu fun(self: self): boolean
---@field get_selected_candidate fun(self: self): Candidate|nil
---@field push_input fun(self: self, text: string): boolean
---@field pop_input fun(self: self, len: integer): boolean
---@field delete_input fun(self: self, len: integer): boolean
---@field clear fun(self: self)
---@field select fun(self: self, index: integer): boolean
---@field highlight fun(self: self, index: integer): boolean
---@field confirm_current_selection fun(self: self): boolean
---@field delete_current_selection fun(self: self): boolean
---@field confirm_previous_selection fun(self: self): boolean
---@field reopen_previous_selection fun(self: self): boolean
---@field clear_previous_segment fun(self: self): boolean
---@field reopen_previous_segment fun(self: self): boolean
---@field clear_non_confirmed_composition fun(self: self): boolean
---@field refresh_non_confirmed_composition fun(self: self): boolean
---@field set_option fun(self: self, name: string, value: boolean)
---@field get_option fun(self: self, name: string): boolean
---@field set_property fun(self: self, key: string, value: string)
---@field get_property fun(self: self, key: string): string
---@field clear_transient_options fun(self: self)

---@class Preedit
---@field text string
---@field caret_pos integer
---@field sel_start integer
---@field sel_end integer

---@class Composition
---@field empty fun(self: self): boolean
---@field back fun(self: self): Segment|nil
---@field pop_back fun(self: self)
---@field push_back fun(self: self, seg: Segment)
---@field has_finished_composition fun(self: self): boolean
---@field get_prompt fun(self: self): string
---@field toSegmentation fun(self: self): Segmentation
---@field spans fun(self: self): Spans

---@class Segmentation
---@field input string
---@field size integer
---@field empty fun(self: self): boolean
---@field back fun(self: self): Segment|nil
---@field pop_back fun(self: self)
---@field reset_length fun(self: self, length: integer)
---@field add_segment fun(self: self, seg: Segment): boolean
---@field forward fun(self: self): boolean
---@field trim fun(self: self): boolean
---@field has_finished_segmentation fun(self: self): boolean
---@field get_current_start_position fun(self: self): integer
---@field get_current_end_position fun(self: self): integer
---@field get_current_segment_length fun(self: self): integer
---@field get_confirmed_position fun(self: self): integer
---@field get_segments fun(self: self): Segment[]
---@field get_at fun(self: self, index: integer): Segment|nil 负数从末尾数起，越界时返回 nil

---@class Segment
---@field status SegmentType
---@field start integer
---@field _start integer
---@field _end integer
---@field length integer
---@field tags Set
---@field menu Menu
---@field selected_index integer
---@field prompt string
---@field clear fun(self: self)
---@field close fun(self: self)
---@field reopen fun(self: self, caret_pos: integer): boolean
---@field has_tag fun(self: self, tag: string): boolean
---@field get_candidate_at fun(self: self, index: integer): Candidate
---@field get_selected_candidate fun(self: self): Candidate
---@field active_text fun(self: self, text: string): string
---@field spans fun(self: self): Spans

---@param start_pos integer
---@param end_pos integer
---@return Segment
function Segment(start_pos, end_pos) end

---@class Schema
---@field schema_id string
---@field schema_name string
---@field config Config
---@field page_size integer
---@field select_keys string

---@param schema_id string
---@return Schema
function Schema(schema_id) end

---@class Config
---@field load_from_file fun(self: self, filename: string): boolean
---@field save_to_file fun(self: self, filename: string): boolean
---@field is_null fun(self: self, conf_path: string): boolean
---@field is_value fun(self: self, conf_path: string): boolean
---@field is_list fun(self: self, conf_path: string): boolean
---@field is_map fun(self: self, conf_path: string): boolean
---@field get_string fun(self: self, conf_path: string): string|nil
---@field get_bool fun(self: self, conf_path: string): boolean|nil
---@field get_int fun(self: self, conf_path: string): integer|nil
---@field get_double fun(self: self, conf_path: string): number|nil
---@field set_string fun(self: self, conf_path: string, s: string): boolean
---@field set_bool fun(self: self, conf_path: string, b: boolean): boolean
---@field set_int fun(self: self, conf_path: string, i: integer): boolean
---@field set_double fun(self: self, conf_path: string, f: number): boolean
---@field get_item fun(self: self, conf_path: string): ConfigItem|nil
---@field set_item fun(self: self, conf_path: string, item: ConfigItem): boolean
---@field get_value fun(self: self, conf_path: string): ConfigValue|nil
---@field set_value fun(self: self, conf_path: string, value: ConfigValue): boolean
---@field get_list fun(self: self, conf_path: string): ConfigList|nil
---@field set_list fun(self: self, conf_path: string, list: ConfigList): boolean
---@field get_map fun(self: self, conf_path: string): ConfigMap|nil
---@field set_map fun(self: self, conf_path: string, map: ConfigMap): boolean
---@field get_list_size fun(self: self, conf_path: string): integer

--- 传入文件名时从该文件加载
---@param filename? string
---@return Config
function Config(filename) end

---@class ConfigItem
---@field type ConfigType
---@field empty boolean
---@field get_value fun(self: self): ConfigValue|nil
---@field get_map fun(self: self): ConfigMap|nil
---@field get_list fun(self: self): ConfigList|nil
---@field get_obj fun(self: self): ConfigMap|ConfigList|ConfigValue|nil

---@class ConfigMap
---@field type ConfigType
---@field size integer
---@field element ConfigItem
---@field empty fun(self: self): boolean
---@field has_key fun(self: self, key: string): boolean
---@field keys fun(self: self): string[]
---@field get fun(self: self, key: string): ConfigItem|nil
---@field get_value fun(self: self, key: string): ConfigValue|nil
---@field set fun(self: self, key: string, item: ConfigItem): boolean
---@field clear fun(self: self): boolean

---@return ConfigMap
function ConfigMap() end

---@class ConfigList
---@field type ConfigType
---@field size integer
---@field element ConfigItem
---@field empty fun(self: self): boolean
---@field get_at fun(self: self, index: integer): ConfigItem|nil
---@field get_value_at fun(self: self, index: integer): ConfigValue|nil
---@field set_at fun(self: self, index: integer, item: ConfigItem): boolean
---@field append fun(self: self, item: ConfigItem): boolean
---@field insert fun(self: self, i: integer, item: ConfigItem): boolean
---@field clear fun(self: self): boolean
---@field resize fun(self: self, size: integer): boolean

---@return ConfigList
function ConfigList() end

---@class ConfigValue
---@field type ConfigType
---@field value string|nil
---@field element ConfigItem
---@field get_string fun(self: self): string|nil
---@field get_bool fun(self: self): boolean|nil
---@field get_int fun(self: self): integer|nil
---@field get_double fun(self: self): number|nil
---@field set_string fun(self: self, s: string): boolean
---@field set_bool fun(self: self, b: boolean): boolean
---@field set_int fun(self: self, i: integer): boolean
---@field set_double fun(self: self, f: number): boolean

---@param value? string|boolean
---@return ConfigValue
function ConfigValue(value) end

---@class KeyEvent
---@field keycode integer
---@field modifier integer
---@field shift fun(self: self): boolean
---@field ctrl fun(self: self): boolean
---@field alt fun(self: self): boolean
---@field caps fun(self: self): boolean
---@field super fun(self: self): boolean
---@field release fun(self: self): boolean
---@field repr fun(self: self): string
---@field eq fun(self: self, key: KeyEvent): boolean
---@field lt fun(self: self, key: KeyEvent): boolean

---@param repr string
---@return KeyEvent
---@overload fun(keycode: integer, modifier: integer): KeyEvent
function KeyEvent(repr) end

---@class KeySequence
---@field parse fun(self: self, repr: string): boolean
---@field repr fun(self: self): string
---@field toKeyEvent fun(self: self): KeyEvent[]

---@param repr? string
---@return KeySequence
function KeySequence(repr) end

---@class Candidate
---@field type string
---@field start integer
---@field _start integer
---@field _end integer
---@field quality number
---@field text string 只有 Simple 候选可写
---@field comment string 只有 Simple、Phrase 候选可写
---@field preedit string 只有 Simple、Phrase 候选可写
---@field get_dynamic_type fun(self: self): "Sentence"|"Phrase"|"Simple"|"Shadow"|"Uniquified"|"Other"
---@field get_genuine fun(self: self): Candidate
---@field get_genuines fun(self: self): Candidate[]
---@field to_shadow_candidate fun(self: self, type: string, text?: string, comment?: string, inherit_comment?: boolean): ShadowCandidate
---@field to_uniquified_candidate fun(self: self, type: string, text?: string, comment?: string): UniquifiedCandidate
---@field to_phrase fun(self: self): Phrase|nil
---@field to_sentence fun(self: self): Sentence|nil
---@field append fun(self: self, cand: Candidate): boolean 只对 UniquifiedCandidate 有效
---@field spans fun(self: self): Spans

---@param type string
---@param start integer
---@param _end integer
---@param text string
---@param comment string
---@return Candidate
function Candidate(type, start, _end, text, comment) end

---@class UniquifiedCandidate: Candidate

---@param cand Candidate
---@param type string
---@param text? string
---@param comment? string
---@return UniquifiedCandidate
function UniquifiedCandidate(cand, type, text, comment) end

---@class ShadowCandidate: Candidate

--- text 为空时沿用 cand 的文字；inherit_comment 默认为 true
---@param cand Candidate
---@param type string
---@param text? string
---@param comment? string
---@param inherit_comment? boolean
---@return ShadowCandidate
function ShadowCandidate(cand, type, text, comment, inherit_comment) end

---@class Phrase
---@field language userdata
---@field lang_name string
---@field type string
---@field start integer
---@field _start integer
---@field _end integer
---@field quality number
---@field text string
---@field comment string
---@field preedit string
---@field weight number
---@field code Code
---@field entry DictEntry
---@field toCandidate fun(self: self): Candidate
---@field spans fun(self: self): Spans

---@param memory Memory
---@param type string
---@param start integer
---@param _end integer
---@param entry DictEntry
---@return Phrase
function Phrase(memory, type, start, _end, entry) end

---@class Sentence
---@field language userdata
---@field lang_name string
---@field type string
---@field start integer
---@field _start integer
---@field _end integer
---@field quality number
---@field text string
---@field comment string
---@field preedit string
---@field weight number
---@field code Code
---@field entry DictEntry
---@field word_lengths integer[]
---@field entrys DictEntry[]
---@field entrys_size integer
---@field entrys_empty boolean
---@field toCandidate fun(self: self): Candidate

---@class Spans
---@field _start integer
---@field _end integer
---@field count integer
---@field vertices integer[]
---@field add_span fun(self: self, start: integer, _end: integer)
---@field add_spans fun(self: self, spans: Spans)
---@field add_vertex fun(self: self, vertex: integer)
---@field previous_stop fun(self: self, caret_pos: integer): integer
---@field next_stop fun(self: self, caret_pos: integer): integer
---@field has_vertex fun(self: self, vertex: integer): boolean
---@field count_between fun(self: self, start: integer, _end: integer): integer
---@field clear fun(self: self)

---@return Spans
function Spans() end

--- 以元素为键、值为 true 的表；`+` 并集，`-` 差集，`*` 交集
---@class Set: { [string]: true }
---@operator add(Set): Set
---@operator sub(Set): Set
---@operator mul(Set): Set
---@field empty fun(self: self): boolean

---@param values string[]
---@return Set
function Set(values) end

---@class Menu
---@field add_translation fun(self: self, translation: Translation)
---@field prepare fun(self: self, candidate_count: integer): integer
---@field get_candidate_at fun(self: self, i: integer): Candidate|nil
---@field candidate_count fun(self: self): integer
---@field empty fun(self: self): boolean

---@return Menu
function Menu() end

---@class Translation
---@field exhausted boolean
---@field iter fun(self: self): fun(): Candidate|nil

--- 以生成函数构造，函数里用 yield 产出候选，其余参数原样传给它
---@param func fun(...)
---@param ... any
---@return Translation
function Translation(func, ...) end

---@class Opencc
---@field convert fun(self: self, text: string): string
---@field convert_text fun(self: self, text: string): string
---@field random_convert_text fun(self: self, text: string): string
---@field convert_word fun(self: self, text: string): string[]|nil

--- 配置文件不存在或加载失败时返回 nil
---@param filename string
---@return Opencc|nil
function Opencc(filename) end

---@class Dictionary
---@field name string
---@field loaded boolean
---@field lookup_words fun(self: self, code: string, predictive: boolean, limit: integer): DictEntryIterator
---@field decode fun(self: self, code: Code): string[]

---@class DictEntryIterator
---@field exhausted boolean
---@field size integer
---@field iter fun(self: self): fun(): DictEntry|nil

---@class UserDictionary
---@field name string
---@field loaded boolean
---@field tick integer
---@field lookup_words fun(self: self, code: string, predictive: boolean, limit: integer): UserDictEntryIterator
---@field update_entry fun(self: self, entry: DictEntry, commit: integer, prefix: string, lang_name: string): boolean

---@class UserDictEntryIterator
---@field exhausted boolean
---@field size integer
---@field iter fun(self: self): fun(): DictEntry|nil

---@class ReverseDb
---@field lookup fun(self: self, key: string): string

---@param file_name string
---@return ReverseDb
function ReverseDb(file_name) end

---@class ReverseLookup
---@field lookup fun(self: self, key: string): string
---@field lookup_stems fun(self: self, key: string): string

--- 词典不存在或加载失败时返回 nil
---@param dict_name string
---@return ReverseLookup|nil
function ReverseLookup(dict_name) end

---@class DictEntry
---@field text string
---@field comment string
---@field preedit string
---@field weight number
---@field commit_count integer
---@field custom_code string 如 "hao"、"ni hao"
---@field remaining_code_length integer 如 "~ao" 的长度
---@field code Code

--- 传入 entry 时复制一份
---@param entry? DictEntry
---@return DictEntry
function DictEntry(entry) end

---@class CommitEntry
---@field get fun(self: self): DictEntry[]
---@field update_entry fun(self: self, entry: DictEntry, commit: integer, prefix: string): boolean
---@field update fun(self: self, commit: integer): boolean

---@class Code
---@field push fun(self: self, syllable_id: integer)
---@field print fun(self: self): string

---@return Code
function Code() end

---@class Memory
---@field lang_name string
---@field dict Dictionary
---@field user_dict UserDictionary
---@field start_session fun(self: self): boolean
---@field finish_session fun(self: self): boolean
---@field discard_session fun(self: self): boolean
---@field dict_lookup fun(self: self, input: string, predictive: boolean, limit: integer): boolean
---@field user_lookup fun(self: self, input: string, predictive: boolean): boolean
---@field dictiter_lookup fun(self: self, input: string, predictive: boolean, limit: integer): DictEntryIterator
---@field useriter_lookup fun(self: self, input: string, predictive: boolean): UserDictEntryIterator
---@field memorize fun(self: self, callback: fun(commit_entry: CommitEntry): boolean)
---@field decode fun(self: self, code: Code): string[]
---@field iter_dict fun(self: self): fun(): DictEntry|nil
---@field iter_user fun(self: self): fun(): DictEntry|nil
---@field update_userdict fun(self: self, entry: DictEntry, commit: integer, prefix: string): boolean
---@field update_entry fun(self: self, entry: DictEntry, commit: integer, prefix: string, lang_name: string): boolean
---@field update_candidate fun(self: self, candidate: Candidate, commit: integer): boolean
---@field disconnect fun(self: self)

---@param engine Engine
---@param schema Schema
---@param name_space? string
---@return Memory
function Memory(engine, schema, name_space) end

---@class Projection
---@field load fun(self: self, rules: ConfigList|string[]): boolean
---@field apply fun(self: self, str: string, ret_org_str?: boolean): string 不匹配时返回空串，ret_org_str 为真则返回原串

---@param rules? ConfigList|string[]
---@return Projection
function Projection(rules) end

--- 用 schema 参数可以让组件读另一个方案的配置。klass 为 table_translator、script_translator 时
--- Component.Translator 转交 Component.TableTranslator、Component.ScriptTranslator
Component = {}

---@param engine Engine
---@param name_space string
---@param klass string
---@return Processor
---@overload fun(engine: Engine, schema: Schema, name_space: string, klass: string): Processor
function Component.Processor(engine, name_space, klass) end

---@param engine Engine
---@param name_space string
---@param klass string
---@return Segmentor
---@overload fun(engine: Engine, schema: Schema, name_space: string, klass: string): Segmentor
function Component.Segmentor(engine, name_space, klass) end

---@param engine Engine
---@param name_space string
---@param klass string
---@return Translator
---@overload fun(engine: Engine, schema: Schema, name_space: string, klass: string): Translator
function Component.Translator(engine, name_space, klass) end

---@param engine Engine
---@param name_space string
---@param klass string
---@return Filter
---@overload fun(engine: Engine, schema: Schema, name_space: string, klass: string): Filter
function Component.Filter(engine, name_space, klass) end

---@param engine Engine
---@param name_space string
---@param klass string
---@return TableTranslator
---@overload fun(engine: Engine, schema: Schema, name_space: string, klass: string): TableTranslator
function Component.TableTranslator(engine, name_space, klass) end

---@param engine Engine
---@param name_space string
---@param klass string
---@return ScriptTranslator
---@overload fun(engine: Engine, schema: Schema, name_space: string, klass: string): ScriptTranslator
function Component.ScriptTranslator(engine, name_space, klass) end

---@class Processor
---@field name_space string
---@field process_key_event fun(self: self, key_event: KeyEvent): ProcessResult

---@class Segmentor
---@field name_space string
---@field proceed fun(self: self, segmentation: Segmentation): boolean

---@class Translator
---@field name_space string
---@field query fun(self: self, input: string, segment: Segment): Translation|nil

---@class Filter
---@field name_space string
---@field apply fun(self: self, translation: Translation): Translation
---@field applies_to_segment fun(self: self, segment: Segment): boolean

--- TableTranslator 和 ScriptTranslator 共有的成员
---@class LuaTranslator: Translator
---@field lang_name string
---@field memorize_callback fun(translator: self, commit_entry: CommitEntry): boolean | nil 设为 nil 时恢复默认的 memorize
---@field delimiters string
---@field tag string
---@field enable_completion boolean
---@field contextual_suggestions boolean
---@field strict_spelling boolean
---@field initial_quality number
---@field preedit_formatter Projection
---@field comment_formatter Projection
---@field dict Dictionary
---@field user_dict UserDictionary
---@field translator Translator
---@field start_session fun(self: self): boolean
---@field finish_session fun(self: self): boolean
---@field discard_session fun(self: self): boolean
---@field memorize fun(self: self, commit_entry: CommitEntry): boolean 原生的 Memorize，可在 memorize_callback 里调用
---@field update_entry fun(self: self, entry: DictEntry, commit: integer, prefix: string): boolean
---@field reload_user_dict_disabling_patterns fun(self: self, patterns: ConfigList): boolean
---@field set_memorize_callback fun(self: self, callback: fun(translator: self, commit_entry: CommitEntry): boolean | nil): boolean
---@field disconnect fun(self: self)

---@class TableTranslator: LuaTranslator
---@field enable_charset_filter boolean
---@field enable_encoder boolean
---@field enable_sentence boolean
---@field sentence_over_completion boolean
---@field encode_commit_history boolean
---@field max_phrase_length integer
---@field max_homographs integer

---@class ScriptTranslator: LuaTranslator
---@field max_homophones integer
---@field spelling_hints integer
---@field always_show_comments boolean
---@field enable_correction boolean

---@class Notifier
---@field connect fun(self: self, f: fun(ctx: Context), group: integer|nil): Connection

---@class OptionUpdateNotifier: Notifier
---@field connect fun(self: self, f: fun(ctx: Context, name: string), group: integer|nil): Connection

---@class PropertyUpdateNotifier: Notifier
---@field connect fun(self: self, f: fun(ctx: Context, name: string), group: integer|nil): Connection

---@class KeyEventNotifier: Notifier
---@field connect fun(self: self, f: fun(ctx: Context, key_event: KeyEvent), group: integer|nil): Connection

---@class Connection
---@field disconnect fun(self: self)

---@class Switcher
---@field attached_engine Engine
---@field user_config Config
---@field active boolean
---@field process_key fun(self: self, key_event: KeyEvent): ProcessResult
---@field select_next_schema fun(self: self)
---@field is_auto_save fun(self: self, option: string): boolean
---@field refresh_menu fun(self: self)
---@field activate fun(self: self)
---@field deactivate fun(self: self)

---@param engine Engine
---@return Switcher
function Switcher(engine) end

---@class CommitRecord
---@field text string
---@field type string

---@class CommitHistory
---@field size integer
---@field push fun(self: self, key_event: KeyEvent) | fun(self: self, composition: Composition, input: string) | fun(self: self, type: string, text: string)
---@field back fun(self: self): CommitRecord|nil
---@field to_table fun(self: self): CommitRecord[]
---@field iter fun(self: self): fun(): userdata, CommitRecord 从新到旧
---@field repr fun(self: self): string
---@field latest_text fun(self: self): string
---@field empty fun(self: self): boolean
---@field clear fun(self: self)
---@field pop_back fun(self: self)

---@class DbAccessor
---@field reset fun(self: self): boolean
---@field jump fun(self: self, prefix: string): boolean
---@field iter fun(self: self): fun(): string, string

---@class UserDb
---@field _loaded boolean
---@field read_only boolean
---@field disabled boolean
---@field name string
---@field file_name string
---@field open fun(self: self): boolean
---@field open_read_only fun(self: self): boolean
---@field close fun(self: self): boolean
---@field query fun(self: self, prefix: string): DbAccessor
---@field fetch fun(self: self, key: string): string|nil
---@field update fun(self: self, key: string, value: string): boolean
---@field erase fun(self: self, key: string): boolean
---@field loaded fun(self: self): boolean
---@field disable fun(self: self)
---@field enable fun(self: self)

---@param db_name string
---@param db_class "userdb"|"plain_userdb"
---@return UserDb
function UserDb(db_name, db_class) end

---@class LevelDb: UserDb

---@param db_name string
---@return LevelDb
function LevelDb(db_name) end

---@class TableDb: UserDb

---@param db_name string
---@return TableDb
function TableDb(db_name) end
