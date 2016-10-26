/* eslint-disable */

((global) => {
  const UNFOLD_COUNT = 20;

  class Diff {
    constructor() {
      $('.files .diff-file').singleFileDiff();
      $('.files .diff-file').filesCommentButton();

      if (this.diffViewType() === 'parallel') {
        $('.content-wrapper .container-fluid').removeClass('container-limited');
      }

      $(document)
        .off('click', '.js-unfold, .diff-line-num a')
        .on('click', '.js-unfold', this.handleClickUnfold.bind(this))
        .on('click', '.diff-line-num a', this.handleClickLineNum.bind(this));

      this.highlighSelectedLine();
    }

    handleClickUnfold(event) {
      const $target = $(event.target);
      const [oldLineNumber, newLineNumber] = this.lineNumbers($target.parent());
      const offset = newLineNumber - oldLineNumber;
      const bottom = $target.hasClass('js-unfold-bottom');
      let since, to;
      let unfold = true;

      if (bottom) {
        const lineNumber = newLineNumber + 1;
        since = lineNumber;
        to = lineNumber + UNFOLD_COUNT;
      } else {
        const lineNumber = newLineNumber - 1;
        since = lineNumber - UNFOLD_COUNT;
        to = lineNumber;

        // make sure we aren't loading more than we need
        const [prevOldLine, prevNewLine] = this.lineNumbers($target.parent().prev());
        if (since <= prevNewLine + 1) {
          since = prevNewLine + 1;
          unfold = false;
        }
      }

      const file = $target.parents('.diff-file');
      const link = file.data('blob-diff-path');
      const view = file.data('view');

      const params = { since, to, bottom, offset, unfold, view };
      $.get(link, params, (response) => $target.parent().replaceWith(response));
    }

    handleClickLineNum(event) {
      const hash = $(event.currentTarget).attr('href');
      event.preventDefault();
      if (history.pushState) {
        history.pushState(null, null, hash);
      } else {
        window.location.hash = hash;
      }
      this.highlighSelectedLine();
    };

    diffViewType() {
      return $('.inline-parallel-buttons a.active').data('view-type');
    }

    lineNumbers(line) {
      if (!line.children().length) {
        return [0, 0];
      }

      return line.find('.diff-line-num').map(function() {
        return parseInt($(this).data('linenumber'));
      });
    }

    highlighSelectedLine() {
      const $diffFiles = $('.diff-file');
      $diffFiles.find('.hll').removeClass('hll');

      if (window.location.hash !== '') {
        const hash = window.location.hash.replace('#', '');
        $diffFiles
          .find(`tr#${hash}:not(.match) td, td#${hash}, td[data-line-code="${hash}"]`)
          .addClass('hll');
      }
    }
  }

  global.Diff = Diff;

})(window.gl || (window.gl = {}));
