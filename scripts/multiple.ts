import { addDict, customPinyin, pinyin, convert } from "pinyin-pro";
import CompleteDict from "@pinyin-pro/data/complete.json";
import { mkdirSync, readFileSync, writeFileSync } from "fs";
import matter from "gray-matter";
const diff2 = {
	这个: "zhè gè",
	部分: "bù fèn",
	任务: "rèn wù",
	那个: "nà gè",
	皇上: "huáng shàng",
	认识: "rèn shí",
	师父: "shī fù",
	知识: "zhī shí",
	行当: "háng dàng",
	道行: "dào héng",
	胖子: "pàng zǐ",
	答应: "dā yìng",
	太监: "tài jiàn",
	休息: "xiū xī",
	合同: "hé tóng",
	头发: "tóu fà",
	要是: "yào shì",
	路上: "lù shàng",
	大夫: "dài fū",
	便宜: "pián yí",
	石头: "shí tóu",
	漂亮: "piào liàng",
	弟兄: "dì xiōng",
	丫头: "yā tóu",
	弟弟: "dì dì",
	王爷: "wáng yé",
	家伙: "jiā huǒ",
	椅子: "yǐ zǐ",
	念头: "niàn tóu",
	寻思: "xún sī",
	亲戚: "qīn qī",
	胳膊: "gē bó",
	咳嗽: "ké sòu",
	叶子: "yè zǐ",
	模糊: "mó hú",
	称呼: "chēng hū",
	委屈: "wěi qū",
	伯伯: "bó bó",
	圈子: "quān zǐ",
	见识: "jiàn shí",
	都督: "dū dū",
	相公: "xiàng gōng",
	打量: "dǎ liáng",
	舌头: "shé tóu",
	行李: "xíng lǐ",
	孙子: "sūn zǐ",
	拳头: "quán tóu",
	骨头: "gǔ tóu",
	馒头: "mán tóu",
	头儿: "tóu ér",
	折腾: "zhē téng",
	木头: "mù tóu",
	动弹: "dòng tán",
	少爷: "shào yé",
	尾巴: "wěi bā",
	哑巴: "yǎ bā",
	车子: "chē zǐ",
	担子: "dàn zǐ",
	女婿: "nǚ xù",
	被子: "bèi zǐ",
	吆喝: "yāo hè",
	里头: "lǐ tóu",
	伺候: "cì hòu",
	枕头: "zhěn tóu",
	外头: "wài tóu",
	结实: "jiē shí",
	王八: "wáng bā",
	句子: "jù zǐ",
	扎实: "zhā shí",
	指头: "zhǐ tóu",
	畜生: "chù shēng",
	棍子: "gùn zǐ",
	含糊: "hán hū",
	扇子: "shàn zǐ",
	喇叭: "lǎ bā",
	燕子: "yàn zǐ",
	个子: "gè zǐ",
	会儿: "huì ér",
	作坊: "zuō fáng",
	风筝: "fēng zhēng",
	屯子: "tún zǐ",
	罪过: "zuì guò",
	曲子: "qǔ zǐ",
	应酬: "yìng chóu",
	前头: "qián tóu",
	杆子: "gān zǐ",
	后头: "hòu tóu",
	约莫: "yuē mò",
	帖子: "tiě zǐ",
	吓唬: "xià hǔ",
	沙子: "shā zǐ",
	别扭: "biè nǐu",
	思量: "sī liáng",
	盖子: "gài zǐ",
	条子: "tiáo zǐ",
	姥姥: "lǎo lǎo",
	迷糊: "mí hū",
	蛤蟆: "há má",
	钉子: "dīng zǐ",
	巴结: "bā jié",
	扫帚: "sào zhǒu",
	头子: "tóu zǐ",
	裁缝: "cái féng",
	倒腾: "dǎo téng",
	嚷嚷: "rāng rāng",
	柜子: "guì zǐ",
	膏药: "gāo yào",
	估量: "gū liáng",
	相声: "xiàng shēng",
	片子: "piān zǐ",
	尺子: "chǐ zǐ",
	斗篷: "dǒu péng",
	铺子: "pù zǐ",
	底子: "dǐ zǐ",
	锄头: "chú tóu",
	疟疾: "nüè jí",
	唠叨: "láo dāo",
	妃子: "fēi zǐ",
	卷子: "juàn zǐ",
	巷子: "xiàng zǐ",
	风头: "fēng tóu",
	格子: "gé zǐ",
	调子: "diào zǐ",
	转悠: "zhuàn yōu",
	爪子: "zhuǎ zǐ",
	单子: "dān zǐ",
	用处: "yòng chù",
	窝囊: "wō náng",
	知会: "zhī huì",
	日头: "rì tóu",
	化子: "huà zǐ",
	栅栏: "zhà lán",
	场子: "chǎng zǐ",
	兴头: "xìng tóu",
	约摸: "yuē mō",
	空儿: "kòng ér",
	估摸: "gū mō",
	厂子: "chǎng zǐ",
	跟头: "gēn tóu",
	累赘: "léi zhuì",
	哈欠: "hā qiàn",
	空子: "kòng zǐ",
	刷子: "shuā zǐ",
	塞子: "sāi zǐ",
	兆头: "zhào tóu",
	啊哈: "ā hā",
	准头: "zhǔn tóu",
	佛爷: "fó yé",
	薄荷: "bò hé",
	来头: "lái tóu",
	冒失: "mào shī",
	眯缝: "mī fèng",
	号子: "hào zǐ",
	拾掇: "shí duō",
	簸箕: "bò jī",
	磨蹭: "mó cèng",
	蚂蚱: "mà zhà",
	撮合: "cuō hé",
	趔趄: "liè qiè",
	台子: "tái zǐ",
	行头: "xíng tóu",
	炮仗: "pào zhàng",
	凉快: "liáng kuài",
	溜达: "liū dá",
	苗头: "miáo tóu",
	勾搭: "gōu dā",
	份子: "fèn zǐ",
	结巴: "jiē bā",
	杠子: "gàng zǐ",
	夹子: "jiā zǐ",
	铃铛: "líng dāng",
	糊糊: "hū hū",
	浪头: "làng tóu",
	模子: "mú zǐ",
	芋头: "yù tóu",
	跳蚤: "tiào zǎo",
	挑子: "tiāo zǐ",
	盖头: "gài tóu",
	答理: "dā lǐ",
	晃荡: "huàng dàng",
	臊子: "sào zǐ",
	度数: "dù shù",
	姘头: "pīn tóu",
	浆糊: "jiàng hù",
	看头: "kàn tóu",
	盼头: "pàn tóu",
	弥撒: "mí sā",
	里子: "lǐ zǐ",
	调调: "diào diào",
	捻子: "niǎn zǐ",
	骨碌: "gū lù",
	碌碡: "liù zhóu",
	片儿: "piàn ér",
	叉子: "chā zǐ",
	蛾子: "é zǐ",
	簿子: "bù zǐ",
	奔头: "bèn tóu",
	乐子: "lè zǐ",
	乜斜: "miē xié",
	划拉: "huá lā",
	絮叨: "xù dāo",
	扎挣: "zhá zhēng",
	垛子: "duò zǐ",
	糨糊: "jiàng hù",
	芫荽: "yán suī",
	芥末: "jiè mò",
	酌量: "zhuó liàng",
	榔头: "láng tóu",
	赚头: "zhuàn tóu",
	想头: "xiǎng tóu",
	宽绰: "kuān chuò",
	核儿: "hú ér",
	缝子: "fèng zǐ",
	骨子: "gǔ zǐ",
	叨咕: "dáo gū",
	笼子: "lóng zǐ",
	爷爷: "yé yé",
	奶奶: "nǎi nǎi",
	姥爷: "lǎo yé",
	爸爸: "bà bà",
	妈妈: "mā mā",
	婶婶: "shěn shěn",
	舅舅: "jiù jìu",
	姑姑: "gū gū",
	叔叔: "shū shū",
	姨夫: "yí fū",
	舅母: "jiù mǔ",
	姑父: "gū fù",
	姐夫: "jiě fū",
	婆婆: "pó pó",
	公公: "gōng gōng",
	舅子: "jiù zǐ",
	姐姐: "jiě jiě",
	哥哥: "gē gē",
	妹妹: "mèi mèi",
	妹夫: "mèi fū",
	姨子: "yí zǐ",
	宝宝: "bǎo bǎo",
	娃娃: "wá wá",
	孩子: "hái zǐ",
	日子: "rì zǐ",
	样子: "yàng zǐ",
	狮子: "shī zǐ",
	身子: "shēn zǐ",
	架子: "jià zǐ",
	嫂子: "sǎo zǐ",
	鼻子: "bí zǐ",
	亭子: "tíng zǐ",
	折子: "zhé zǐ",
	面子: "miàn zǐ",
	脖子: "bó zǐ",
	辈子: "bèi zǐ",
	帽子: "mào zǐ",
	拍子: "pāi zǐ",
	柱子: "zhù zǐ",
	辫子: "biàn zǐ",
	鸽子: "gē zǐ",
	房子: "fáng zǐ",
	丸子: "wán zǐ",
	摊子: "tān zǐ",
	牌子: "pái zǐ",
	胡子: "hú zǐ",
	鬼子: "guǐ zǐ",
	矮子: "ǎi zǐ",
	鸭子: "yā zǐ",
	小子: "xiǎo zǐ",
	影子: "yǐng zǐ",
	屋子: "wū zǐ",
	对子: "duì zǐ",
	点子: "diǎn zǐ",
	本子: "běn zǐ",
	种子: "zhǒng zǐ",
	儿子: "ér zǐ",
	兔子: "tù zǐ",
	骗子: "piàn zǐ",
	院子: "yuàn zǐ",
	猴子: "hóu zǐ",
	嗓子: "sǎng zǐ",
	侄子: "zhí zǐ",
	柿子: "shì zǐ",
	钳子: "qián zǐ",
	虱子: "shī zǐ",
	瓶子: "píng zǐ",
	豹子: "bào zǐ",
	筷子: "kuài zǐ",
	篮子: "lán zǐ",
	绳子: "shéng zǐ",
	嘴巴: "zuǐ bā",
	耳朵: "ěr duǒ",
	茄子: "qié zǐ",
	琵琶: "pí pá",
	蘑菇: "mó gū",
	葫芦: "hú lú",
	狐狸: "hú lí",
	桔子: "jú zǐ",
	盒子: "hé zǐ",
	桌子: "zhuō zǐ",
	竹子: "zhú zǐ",
	师傅: "shī fù",
	衣服: "yī fú",
	袜子: "wà zǐ",
	杯子: "bēi zǐ",
	刺猬: "cì wèi",
	麦子: "mài zǐ",
	队伍: "duì wǔ",
	鱼儿: "yú ér",
	馄饨: "hún tún",
	灯笼: "dēng lóng",
	庄稼: "zhuāng jià",
	聪明: "cōng míng",
	镜子: "jìng zǐ",
	银子: "yín zǐ",
	盘子: "pán zǐ",
	力气: "lì qì",
	席子: "xí zǐ",
	林子: "lín zǐ",
	丈夫: "zhàng fū",
	豆腐: "dòu fǔ",
	喜欢: "xǐ huān",
	生意: "shēng yì",
	眉毛: "méi máo",
	混混: "hùn hùn",
	财主: "cái zhǔ",
	厚道: "hòu dào",
	里脊: "lǐ jǐ",
	格格: "gé gé",
	闺女: "guī nǚ",
	磨叽: "mó jī",
	杠杠: "gàng gàng",
	框框: "kuàng kuàng",
	精神: "jīng shén",
	揉搓: "róu cuō",
	垃圾: "lā jī",
	慢慢: "màn màn",
};
const diff3 = {
	实际上: "shí jì shàng",
	这会儿: "zhè huì ér",
	不在乎: "bú zài hū",
	有点儿: "yǒu diǎn ér",
	发脾气: "fā pí qì",
	压根儿: "yà gēn ér",
	那会儿: "nà huì ér",
	自个儿: "zì gě ér",
	少奶奶: "shào nǎi nǎi",
	山里红: "shān lǐ hóng",
	好好儿: "hǎo hāo ér",
	好意思: "hǎo yì sī",
	没意思: "méi yì sī",
	戏班子: "xì bān zǐ",
	外甥女: "wài shēng nǚ",
	劳什子: "láo shí zǐ",
	知识面: "zhī shí miàn",
	护士长: "hù shì zhǎng",
	枪杆子: "qiāng gǎn zǐ",
	癞蛤蟆: "lài há má",
	脊梁骨: "jǐ liáng gǔ",
	说笑话: "shuō xiào huà",
	玻璃钢: "bō lí gāng",
	软骨头: "ruǎn gǔ tóu",
	打哆嗦: "dǎ duō suō",
	夜猫子: "yè māo zǐ",
	气头上: "qì tóu shàng",
	糊涂虫: "hú tú chóng",
	笔杆子: "bǐ gǎn zǐ",
	占便宜: "zhàn pián yí",
	挨个儿: "āi gè ér",
	那阵儿: "nà zhèn ér",
	大师傅: "dà shī fù",
	打呼噜: "dǎ hū lū",
	广渠门: "guǎng qú mén",
	大婶儿: "dà shěn ér",
	脚丫子: "jiǎo yā zǐ",
	窝里斗: "wō lǐ dòu",
	个头儿: "gè tóu ér",
	糊涂账: "hú tú zhàng",
	大猩猩: "dà xīng xīng",
	闷葫芦: "mèn hú lú",
	哈巴狗: "hǎ bā gǒu",
	石子儿: "shí zǐ ér",
	丁点儿: "dīng diǎn ér",
	傻劲儿: "shǎ jìn ér",
	铅玻璃: "qiān bō lí",
	屎壳郎: "shǐ ké làng",
	尥蹶子: "liào juě zǐ",
	卡脖子: "qiǎ bó zǐ",
	红澄澄: "hóng dèng dèng",
	当间儿: "dāng jiàn ér",
	担担面: "dàn dàn miàn",
	爪尖儿: "zhuǎ jiān ér",
	支着儿: "zhī zhāo ér",
	折跟头: "zhē gēn tóu",
	阴着儿: "yīn zhāo ér",
	烟卷儿: "yān juǎn ér",
	信皮儿: "xìn pí ér",
	水漂儿: "shuǐ piāo ér",
	什件儿: "shí jiàn ér",
	撒呓挣: "sā yì zhèng",
	努劲儿: "nǔ jìn ér",
	泥娃娃: "ní wá wá",
	哪会儿: "nǎ huì ér",
	闷头儿: "mēn tóu ér",
	没谱儿: "méi pǔ ér",
	铆劲儿: "mǎo jìn ér",
	坤角儿: "kūn jué ér",
	汗褂儿: "hàn guà ér",
	够劲儿: "gòu jìn ér",
	嘎渣儿: "gā zhā ér",
	逗闷子: "dòu mèn zǐ",
	滴溜儿: "dī liù ér",
	大轴子: "dà zhòu zǐ",
	打板子: "dǎ bǎn zǐ",
	寸劲儿: "cùn jìn ér",
	醋劲儿: "cù jìn ér",
	揣手儿: "chuāi shǒu ér",
	冲劲儿: "chòng jìn ér",
	奔头儿: "bèn tóu ér",
	娃娃亲: "wá wá qīn",
	死劲儿: "sǐ jìn ér",
	骨朵儿: "gū duǒ ér",
};
const diff4 = {
	迷迷糊糊: "mí mí hū hū",
	不可收拾: "bù kě shōu shí",
	模模糊糊: "mó mó hū hū",
	如之奈何: "rú zhī nài hé",
	踏踏实实: "tā tā shí shí",
	顶头上司: "dǐng tóu shàng sī",
	含含糊糊: "hán hán hū hū",
	玻璃纤维: "bō lí xiān wéi",
	吵吵闹闹: "chāo chāo nào nào",
	唠唠叨叨: "láo láo dāo dāo",
	叽叽喳喳: "jī jī zhā zhā",
	稀里糊涂: "xī lǐ hú tú",
	大大咧咧: "dà dà liē liē",
	粗心大意: "cū xīn dà yì",
	好好先生: "hǎo hǎo xiān shēng",
	骂骂咧咧: "mà mà liē liē",
	河北梆子: "hé běi bāng zǐ",
	正儿八经: "zhèng ér bā jīng",
	不识抬举: "bù shí tái jǔ",
	服服帖帖: "fú fú tiē tiē",
	噼里啪啦: "pī lǐ pā lā",
	稀里哗啦: "xī lǐ huā lā",
	负债累累: "fù zhài lěi lěi",
	没头苍蝇: "méi tóu cāng yíng",
	失而复得: "shī ér fù dé",
	鼓鼓囊囊: "gǔ gǔ nāng nāng",
	有机玻璃: "yǒu jī bō lí",
	骨头架子: "gǔ tóu jià zǐ",
	一丁点儿: "yī dīng diǎn ér",
	吊儿郎当: "diào ér láng dāng",
	河南梆子: "hé nán bāng zǐ",
	漂漂亮亮: "piào piào liàng liàng",
	小家子气: "xiǎo jiā zǐ qì",
	钢化玻璃: "gāng huà bō lí",
	狐狸尾巴: "hú lí wěi bā",
	打马虎眼: "dǎ mǎ hǔ yǎn",
	疙疙瘩瘩: "gē gē dā dā",
	这么点儿: "zhè me diǎn ér",
	绣花枕头: "xiù huā zhěn tóu",
	大人先生: "dà rén xiān shēng",
	多劳多得: "duō láo duō dé",
	曲里拐弯: "qū lǐ guǎi wān",
	哩哩啦啦: "lī lī lā lā",
	夹层玻璃: "jiā céng bō lí",
	攒眉蹙额: "cuán méi cù é",
	与时消息: "yǔ shí xiāo xī",
	香培玉琢: "xiāng péi yù zhuó",
	握粟出卜: "wò sù chū bǔ",
	天宝当年: "tiān bǎo dāng nián",
	数理逻辑: "shù lǐ luó jí",
	石英玻璃: "shí yīng bō lí",
	沙鸥翔集: "shā ōu xiáng jí",
	权倾中外: "quán qīng zhōng wài",
	内修外攘: "nèi xiū wài rǎng",
	内柔外刚: "nèi róu wài gāng",
	内峻外和: "nèi jùn wài hé",
	龙游曲沼: "lóng yóu qū zhǎo",
	牢什古子: "láo shí gǔ zǐ",
	经纶济世: "jīng lún jì shì",
	花不棱登: "huā bù lēng dēng",
	红不棱登: "hóng bù lēng dēng",
	广文先生: "guǎng wén xiān shēng",
	恩不放债: "ēn bú fàng zhài",
	东方将白: "dōng fāng jiāng bái",
	打闷葫芦: "dǎ mèn hú lú",
	谄上抑下: "chǎn shàng yì xià",
	不亦善夫: "bù yì shàn fū",
	叶落归根: "yè luò guī gēn",
	枝大于本: "zhī dà yú běn",
	还珠格格: "huán zhū gé gé",
};
const diff5 = {
	行行出状元: "háng háng chū zhuàng yuán",
	竹筒倒豆子: "zhú tǒng dào dòu zǐ",
};

function getIceFrequency() {
	const frequency = new Map<string, [string, number][]>();
	const tygf = readFileSync("ice/cn_dicts/8105.dict.yaml", "utf-8");
	for (const line of tygf.split("\n")) {
		if (line.startsWith("#")) continue;
		if (!line.includes("\t")) continue;
		const [word, pinyin, freq] = line.split("\t");
		frequency.set(
			word,
			(frequency.get(word) ?? []).concat([[pinyin, parseInt(freq)]]),
		);
	}
	// sort the list in each entry
	for (const [_, list] of frequency) {
		list.sort((a, b) => b[1] - a[1]);
	}
	return frequency;
}

const iceFrequency = getIceFrequency();

function applyDiff(cdict: Map<string, string[]>) {
	const diff1: Record<string, string> = {};
	for (const [word, rawPinyinList] of cdict) {
		const pinyinList = rawPinyinList.map((x) =>
			convert(x.replace("5", "0").replace("v", "ü")),
		);
		const ref = pinyin(word, { multiple: true, nonZh: "removed" });
		const refList = ref.split(" ");
		const getIndex = (p: string) => {
			let index = refList.indexOf(p);
			return index === -1 ? 100 : index;
		};
		pinyinList.sort((a, b) => getIndex(a) - getIndex(b));
		if (ref === word) {
			diff1[word] = pinyinList.join(" ");
		}
	}
	customPinyin(diff1);
	customPinyin(diff2);
	customPinyin(diff3);
	customPinyin(diff4);
	customPinyin(diff5);
}

function resolve(
	word: string,
	simp_list: string[],
	ref_list: string[],
	dict: Map<string, string[]>,
) {
	let resolved = true;
	let chars = [...word];
	const updatedList = ref_list.map((syllable, i) => {
		const char = chars[i];
		const simp = simp_list[i];
		const possible = dict.get(char)!;
		if (syllable.startsWith(simp)) return syllable;
		if (possible.length === 1) return possible[0];
		if (possible.filter((p) => p.startsWith(simp)).length === 1) {
			return possible.find((p) => p.startsWith(simp))!;
		}
		resolved = false;
		return syllable;
	});
	return [resolved, updatedList.join(" ")] as const;
}

function fixDictEntry(
	word: string,
	pinyin_list: string[],
	dict: Map<string, string[]>,
) {
	let resolved = true;
	const updatedList = pinyin_list.map((syllable, i) => {
		const char = word[i];
		const possible = dict
			.get(char)
			?.map((x) => x.replace("5", "0").replace("v", "ü"));
		if (!possible) return syllable;
		const syllableNum = convert(syllable, { format: "symbolToNum" });
		const syllableWithoutTone = syllableNum.replace(/\d/g, "");
		if (possible.includes(syllableNum)) return syllable;
		if (possible.length === 1) return convert(possible[0]);
		if (
			possible.filter((p) => p.startsWith(syllableWithoutTone)).length === 1
		) {
			return convert(possible.find((p) => p.startsWith(syllableWithoutTone))!);
		}
		resolved = false;
		return syllable;
	});
	return [resolved, updatedList.join(" ")] as const;
}

function processCompleteDict() {
	const diff = new Map<string, string>();
	const cdict = getCharacterDict();
	for (const line of readFileSync("scripts/complete-diff.txt", "utf-8").split(
		"\n",
	)) {
		const [key, value] = line.split("\t");
		diff.set(key, value);
	}
	const newDict: Record<string, [string, number, string]> = {};
	const undetermined: string[][] = [];

	for (const [word, value] of Object.entries(CompleteDict)) {
		const pinyin = diff.get(word) ?? value[0];
		const [resolved, updated] = fixDictEntry(word, pinyin.split(" "), cdict);
		newDict[word] = [updated, value[1], value[2]];
		if (!resolved) {
			undetermined.push([word, updated]);
		}
	}

	writeFileSync(
		"diff/complete.txt",
		undetermined.map(([key, value]) => `${key}\t${value}`).join("\n"),
	);
	return newDict;
}

function getCharacterDict() {
	const dict: Map<string, string[]> = new Map();
	const tygf = readFileSync("snow_pinyin.dict.yaml", "utf-8");
	for (const line of tygf.split("\n").slice(83)) {
		if (line.startsWith("#")) continue;
		if (!line.includes("\t")) continue;
		const [word, pinyin] = line.split("\t");
		dict.set(word, (dict.get(word) ?? []).concat(pinyin));
	}
	return dict;
}

function readIceDictionary(name: string) {
	const input = readFileSync(`ice/cn_dicts/${name}.dict.yaml`, "utf-8");
	const data: [string, string, string][] = [];

	for (const line of input.split("\n")) {
		if (line.startsWith("#")) continue;
		if (!line.includes("\t")) continue;
		let [word, simp_pinyin, frequency] = line.split("\t");
		if (frequency === undefined) {
			// 特殊处理 tencent
			frequency = simp_pinyin;
			const normal_word = word.replace(/[·（）：–]/g, "");
			const simp_list = [...normal_word].map((c) => {
				const possible_list = iceFrequency.get(c);
				if (possible_list === undefined) {
					console.log(`Missing ${c}`);
					return "";
				}
				return possible_list[0][0];
			});
			simp_pinyin = simp_list.join(" ");
		}
		data.push([word, simp_pinyin, frequency]);
	}
	return data;
}

export function getPinyin(word: string) {
	return pinyin(word, {
		toneType: "num",
		v: true,
		nonZh: "removed",
		type: "array",
		toneSandhi: false,
	}).map((x) => x.replaceAll("0", "5"));
}

function process(name: string, dict: Map<string, string[]>) {
	const input = readIceDictionary(name);
	const known_words = new Set();
	const undetermined: string[][] = [];
	const determined: string[][] = [];

	for (const [word, simp_pinyin, frequency] of input) {
		const normal_word = word.replace(/[·（）：–]/g, "");
		if (![...normal_word].every((c) => dict.has(c))) continue;
		const simp_list = simp_pinyin.split(" ");
		const ref_list = getPinyin(normal_word);
		const [valid, updated] = resolve(normal_word, simp_list, ref_list, dict);
		if (valid) {
			const hash = word + updated;
			if (known_words.has(hash)) continue;
			determined.push([word, updated, frequency]);
			known_words.add(hash);
		} else {
			undetermined.push([word, ref_list.join(" "), simp_pinyin, frequency]);
		}
	}

	const body = [""].concat(determined.map((row) => row.join("\t"))).join("\n");
	const header = {
		name: `snow_pinyin.${name}`,
		version: "0.2",
		sort: "by_weight",
		use_preset_vocabulary: false,
	};
	const content = matter.stringify(body, header, {
		delimiters: ["---", "..."],
	});

	writeFileSync(`snow_pinyin.${name}.dict.yaml`, content);

	writeFileSync(
		`diff/${name}.txt`,
		undetermined.map((row) => row.join("\t")).join("\n"),
	);
}

function main() {
	mkdirSync("diff", { recursive: true });
	const dict = getCharacterDict();
	applyDiff(dict);
	const completeDict = processCompleteDict();
	addDict(completeDict);
	console.log("初始化完成");
	// process("base", dict);
	// process("ext", dict);
	// process("tencent", dict);
}

main();
