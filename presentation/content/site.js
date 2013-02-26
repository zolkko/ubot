/*
 * vim:set et tabstop=4 shiftwidth=4 nowrap fileencoding=utf-8:
 */

;(function ($) {
    $(function () {
        $(".tabs").click(function (e) {
			$(this).find("li.ui-state-active").removeClass("ui-state-active");
			$(e.target).parents("li").addClass("ui-state-active");
			e.preventDefault();
		});
	});
}) (jQuery);

