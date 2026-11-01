const dvui = @import("dvui");

fn dark() bool {
    return dvui.themeGet().dark;
}

pub fn primary() dvui.ColorOrGradient {
    return if (dark()) .blue else .cyan;
}

pub fn danger() dvui.ColorOrGradient {
    return if (dark()) .maroon else .red;
}

pub fn line() dvui.ColorOrGradient {
    return if (dark()) .cyan else .blue;
}
