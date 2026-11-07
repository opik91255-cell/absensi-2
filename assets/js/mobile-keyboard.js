// Bantu form tetap terlihat ketika keyboard virtual HP terbuka.
(() => {
  const fields = 'input, select, textarea';
  const reveal = (el) => {
    document.body.classList.add('keyboard-open');
    window.setTimeout(() => el.scrollIntoView({ behavior: 'smooth', block: 'center' }), 180);
  };
  document.querySelectorAll(fields).forEach(el => {
    el.addEventListener('focus', () => reveal(el));
    el.addEventListener('blur', () => {
      if (!document.querySelector(`${fields}:focus`)) document.body.classList.remove('keyboard-open');
    });
  });
  if (window.visualViewport) {
    const adjust = () => {
      const vv = window.visualViewport;
      document.documentElement.style.setProperty('--keyboard-space', `${Math.max(0, window.innerHeight - vv.height - vv.offsetTop)}px`);
    };
    window.visualViewport.addEventListener('resize', adjust);
    window.visualViewport.addEventListener('scroll', adjust);
  }
})();
