type HamsterSkinConfig = {
  name: string; // 皮肤名称
  author: string; // 作者名称
  fontface?: FontFace; // 字体名称
  pinyin: KeyboardConfig; // 拼音键盘配置
  alphabetic?: KeyboardConfig; // 字母键盘配置
  numeric: KeyboardConfig; // 数字键盘配置
  symbolic: KeyboardConfig; // 符号键盘配置
};

type FontFaceConfig = {
  url: string; // 字体文件的 URL
  name: string; // 字体名称
  ranges?: { location: number; length: number }[]; // 可选的字体范围
};

type KeyboardConfig = {
  iPhone: {
    portrait: string;
    landscape: string;
  };
  iPad: {
    portrait: string;
    landscape: string;
    floating: string;
  };
};

type Keyboard = {
  preeditHeight: Height;
  preeditStyle: PreeditStyle;
  toolbarHeight: Height;
  toolbarStyle: ToolbarStyle;
  toolbarLayout: Layout;
  horizontalCandidateStyle: HorizontalCandidateStyle;
  horizontalCandidateLayout: Layout;
  verticalCandidateStyle: VerticalCandidateStyle;
  verticalCandidateLayout: Layout;
  candidateContextMenu: CandidateContextMenu;
  keyboardHeight: Height;
  keyboardStyle: KeyboardStyle;
  keyboardLayout: Layout;
  [k: string]: any; // 其他样式或属性
};

// 预编辑区 Preedit

type PreeditStyle = {
  insets: Insets;
  backgroundStyle: Ref<Style>;
  foregroundStyle: Ref<Style>;
};

// 工具栏区 Toolbar

type ToolbarStyle = {
  backgroundStyle: Ref<Style>;
};

type HorizontalCandidateStyle = {
  insets?: Insets;
  backgroundStyle?: Ref<Style>;
};

type HorizontalCandidates = {
  type: 'horizontalCandidates';
  size: Size;
  insets: Insets;
  backgroundStyle: Ref<Style>;
  candidateStyle: Ref<CandidateStyle>;
}

type CandidateStyle = {
  insets?: Insets;
  highlightBackgroundColor?: Color;
  preferredBackgroundColor?: Color;
  preferredIndexColor?: Color;
  preferredTextColor?: Color;
  preferredCommentColor?: Color;
  indexColor?: Color;
  textColor?: Color;
  commentColor?: Color;
  indexFontSize?: number;
  textFontSize?: number;
  commentFontSize?: number;
}

type CandidateStateButtonStyle = {
  backgroundStyle: Ref<CandidateStateButtonBackgroundStyle>;
  foregroundStyle: Refs<CandidateStateButtonForegroundStyle>;
};

type CandidateStateButtonBackgroundStyle = {
  normalColor: string;
  highlightColor: string;
};

type CandidateStateButtonForegroundStyle = {
  normalImage: string;
  highlightImage: string;
};

type VerticalCandidateStyle = {
  insets?: Insets;
  backgroundStyle?: Ref<Style>;
};

type VerticalCandidates = {
  type: 'verticalCandidates';
  maxRows: number;
  separatorColor: '#33338888';
  backgroundStyle: Ref<Style>;
  candidateStyle: Ref<CandidateStyle>;
}

type CandidateContextMenu = CandidateContextMenuItem[];

type CandidateContextMenuItem = {
  name: string;
  action: Action;
};

// 键盘 Keyboard

type KeyboardStyle = {
  backgroundStyle: Ref<Style>;
};

type LayoutElement = CellReference | HStack | VStack;

type CellReference = {
  Cell: Ref<Cell>;
};

type HStack = {
  HStack: {
    subviews: LayoutElement[];
    style?: Ref<StackStyle>;
  };
};

type VStack = {
  VStack: {
    subviews: LayoutElement[];
    style?: Ref<StackStyle>;
  };
};

type StackStyle = {
  size: Size;
};

type Cell = {
  size?: Size;
  bounds?: Bounds;
  backgroundStyle?: BackgroundStyle;
  foregroundStyle: ForegroundStyle;
  uppercasedStateForegroundStyle?: ForegroundStyle;
  capsLockedStateForegroundStyle?: ForegroundStyle;
  hintStyle?: HintStyle;
  hintSymbolsStyle?: HoldSymbolsStyle;

  action?: Action;
  repeatAction?: Action;
  uppercasedStateAction?: Action;
  swipeUpAction?: Action;
  swipeDownAction?: Action;
  animation?: AnimationConfig;
  notification?: NotificationStyle;
};

type HintStyle = {
  insets?: Insets;
  backgroundStyle?: string;
  foregroundStyle?: string;
  swipeUpForegroundStyle?: string;
  swipeDownForegroundStyle?: string;
  swipeLeftForegroundStyle?: string;
  swipeRightForegroundStyle?: string;
};

type HoldSymbolsStyle = {
  insets?: Insets;
  backgroundStyle: string;
  foregroundStyle: string[];
  actions: Action[];
  selectedStyle?: string;
  selectedIndex?: number;
  symbolWidth?: number | string;
};

type CollectionCellStyle = {
  backgroundStyle: string;
  foregroundStyle: string;
};

/*** 行为 ***/

type Action =
  | PrimitiveAction
  | {
      character: string;
    }
  | {
      symbol: string;
    }
  | {
      sendKeys: string;
    }
  | {
      openURL: string;
    }
  | {
      runScript: string;
    }
  | {
      keyboardType:
        | "pinyin"
        | "alphabetic"
        | "numeric"
        | "symbolic"
        | "emojis"
        | string;
    }
  | {
      shortcut: string;
    }
  | {
      switchRimeSchema: string;
    };

type PrimitiveAction =
  | "space"
  | "enter"
  | "tab"
  | "shift"
  | "backspace"
  | "dismissKeyboard"
  | "moveCursorBackward"
  | "moveCursorForward"
  | "returnPrimaryKeyboard"
  | "returnLastKeyboard"
  | "symbolicKeyboardLockStateToggle"
  | "settings"
  | "nextKeyboard";

/*** 动画 ***/

type AnimationConfig = BoundsAnimation | APNGAnimation | EmitAnimation;

type BoundsAnimation = {
  type: "bounds";
  duration: number;
  fromScale: number;
  toScale: number;
  repeatCount?: number;
};

type APNGAnimation = {
  type: "apng";
  file: string;
  targetScale?: number;
  useCellVisibleSize?: boolean;
  zPosition?: number | "above" | "below";
};

type EmitAnimation = {
  type: "emit";
  file: string[];
  duration: number;
  targetScale?: number;
  enableRandomImage?: boolean;
  randomPositionX?: number;
  randomPositionY?: number;
  rotationBegin?: number;
  rotationEnd?: number;
  randomRotation?: number;
  alphaBegin?: number;
  alphaEnd?: number;
};

// 通用定义

type Ref<_> = string;

type Refs<T> = Ref<T> | Ref<T>[];

type Height = number | `${string}vh`;

type Color = string;

type FontSize = number | string;

type TargetScale = number | { x: number; y: number };

type Layout = LayoutElement[];

type ContentMode =
  | "center"
  | "scaleToFill"
  | "scaleAspectFit"
  | "scaleAspectFill";

type ExternalImage = {
  file: string;
  image: string;
};

type Insets = {
  top?: number;
  bottom?: number;
  left?: number;
  right?: number;
};

type Size = {
  width?: number | { percentage: number } | string;
  height?: number | { percentage: number } | string;
};

type Bounds = Size & {
  alignment?:
    | "center"
    | "centerTop"
    | "centerBottom"
    | "left"
    | "right"
    | "leftTop"
    | "leftBottom"
    | "rightTop"
    | "rightBottom";
};

type Point = {
  x: number;
  y: number;
};

type Center = Partial<Point>;

type FontWeight =
  | "ultralight"
  | "thin"
  | "light"
  | "regular"
  | "medium"
  | "semibold"
  | "bold"
  | "heavy"
  | "black";

type BackgroundStyle = Ref<Style>;

type ForegroundStyle = Ref<Style> | Refs<Style>;

type Style =
  | TextStyle
  | GeometryStyle
  | SystemImageStyle
  | AssetImageStyle
  | FileImageStyle;

type TextStyle = {
  buttonStyleType: "text";
  text: string;
  fontSize?: number;
  fontWeight?: FontWeight;
  normalColor: string;
  highlightColor?: string;
  center?: Center;
};

type GeometryStyle = {
  buttonStyleType: "geometry";
  insets?: Insets;
  normalColor: string;
  highlightColor?: string;
  colorLocation?: number[];
  colorStartPoint?: Point;
  colorEndPoint?: Point;
  colorGradientType?: "axial" | "conic" | "radial";
  cornerRadius?: number;
  borderSize?: number;
  normalBorderColor?: string;
  highlightBorderColor?: string;
  normalLowerEdgeColor?: string;
  highlightLowerEdgeColor?: string;
  normalShadowColor?: string;
  highlightShadowColor?: string;
  shadowOpacity?: number;
  shadowRadius?: number;
  shadowOffset?: Point;
  animation?: Ref<AnimationConfig>;
};

type SystemImageStyle = {
  buttonStyleType: "systemImage";
  systemImageName: string;
  highlightSystemImageName?: string;
  contentMode?: ContentMode;
  fontSize?: number;
  fontWeight?: FontWeight;
  normalColor: string;
  highlightColor?: string;
};

type AssetImageStyle = {
  buttonStyleType: "assetImage";
  assetImageName: string;
  contentMode?: ContentMode;
  normalColor: string;
  highlightColor?: string;
};

type FileImageStyle = {
  buttonStyleType: "fileImage";
  insets?: Insets;
  contentMode?: ContentMode;
  normalImage: ExternalImage;
  highlightImage?: ExternalImage;
};

/*** 通知 */

type NotificationStyle = string | string[];

type NotificationType = "rime" | "keyboardAction" | "returnKeyType";

/*** 图片描述文件 ***/

type ImageDescriptionFile = Record<
  string,
  {
    rect: {
      x: number;
      y: number;
      width: number;
      height: number;
    };
    insets: Insets;
  }
>;

/*** 数据源 ***/

type DataSourceValue = string | { label: string; value: string };
type DataSource = Record<string, DataSourceValue[]>;
