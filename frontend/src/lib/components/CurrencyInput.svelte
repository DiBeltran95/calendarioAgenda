<script>
    export let value = 0;
    export let id = '';
    export let required = false;
    export let placeholder = '0';
    export let style = '';
    
    let inputElement;
    let displayValue = '';

    $: {
        if (inputElement && document.activeElement !== inputElement) {
            displayValue = formatNumber(value);
        } else if (!inputElement) {
            displayValue = formatNumber(value);
        }
    }

    function formatNumber(val) {
        if (val === null || val === undefined || val === '') return '';
        if (val === 0) return '0';
        const isNegative = val < 0;
        let str = Math.abs(val).toString();
        // Agrega separadores de miles
        str = str.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
        return isNegative ? '-' + str : str;
    }

    function parseNumber(str) {
        if (!str) return 0;
        const isNegative = str.startsWith('-');
        const cleanStr = str.replace(/[^\d]/g, '');
        if (!cleanStr) return 0;
        const parsed = parseInt(cleanStr, 10);
        return isNegative ? -parsed : parsed;
    }

    function handleInput(e) {
        let rawVal = e.target.value;
        const num = parseNumber(rawVal);
        value = num;
        
        // Conservar el signo menos si el usuario recién lo escribe
        if (rawVal === '-') {
            displayValue = '-';
        } else {
            displayValue = formatNumber(num);
        }
    }

    function handleFocus(e) {
        if (value === 0 || displayValue === '0') {
            displayValue = '';
        }
    }

    function handleBlur(e) {
        if (!displayValue || displayValue === '-') {
            value = 0;
            displayValue = '0';
        }
    }
</script>

<input
    type="text"
    inputmode="numeric"
    {id}
    {required}
    {placeholder}
    {style}
    bind:this={inputElement}
    value={displayValue}
    on:input={handleInput}
    on:focus={handleFocus}
    on:blur={handleBlur}
/>
