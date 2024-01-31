import { Example } from "./Example";

import styles from "./Example.module.css";

export type ExampleModel = {
    text: string;
    value: string;
};

const EXAMPLES: ExampleModel[] = [
    {
        text: "最近のマイクロソフトの取り組みは？",
        value: "最近のマイクロソフトの取り組みは？"
    },
    { text: "マイクロソフトの株価はどうなっていますか？", value: "マイクロソフトの株価はどうなっていますか？" },
    { text: "マイクロソフトの最近のニュースは？", value: "マイクロソフトの最近のニュースは？" }
];

interface Props {
    onExampleClicked: (value: string) => void;
}

export const ExampleList = ({ onExampleClicked }: Props) => {
    return (
        <ul className={styles.examplesNavList}>
            {EXAMPLES.map((x, i) => (
                <li key={i}>
                    <Example text={x.text} value={x.value} onClick={onExampleClicked} />
                </li>
            ))}
        </ul>
    );
};
