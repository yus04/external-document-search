import { Example } from "./Example";

import styles from "./Example.module.css";

export type ExampleModel = {
    text: string;
    value: string;
};

const EXAMPLES: ExampleModel[] = [
    {
        text: "最近のトヨタの取り組みは？",
        value: "最近のトヨタの取り組みは？"
    },
    { text: "半導体の供給状況はどうなっていますか？", value: "半導体の供給状況はどうなっていますか？" },
    { text: "電気自動車市場の成長予測は？", value: "電気自動車市場の成長予測は？" }
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
